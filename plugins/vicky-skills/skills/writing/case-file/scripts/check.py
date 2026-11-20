#!/usr/bin/env python3
"""Refuse a case file that leaks this machine, before it leaves.

Usage: check.py <page.html | page.pdf | page.md | bundle.zip>

Scans the page's text, and every data: download decoded, for loose-lips'
"This machine" kinds: home folders, the nix store, scratch folders under
/tmp, paths from ~ or climbing out with .., this user's name in a path or
address, and this host's name, after HTML entities are decoded. On a page
that names its kind, it also refuses a claim whose visible label differs from
its data-evidence, and the future tense outside a pitch's ask. Exits 1
naming each hit's line or download, 0 when the page is clean. A PDF is read
as text with pdftotext, and one it can't read is refused. A zip is checked
member by member, each hit named by the member it sits in, and a member over
64 MiB is refused unread.
"""
import base64, html, os, re, shutil, socket, subprocess, sys, tempfile, urllib.parse, zipfile

def patterns():
    pats = [r"(?<![\w./-])/(home|Users)/[^/\s\"'<>]+/", r"/nix/store/", r"(?<![\w./-])/tmp/[^\s\"'<>]+", r"(?<![\w.-])~/", r"(?<![\w.])\.\./"]  # local-path-ok: the patterns the check looks for
    home = os.path.expanduser("~")
    if len(home) > 1:
        pats.append(re.escape(home))
    user = os.environ.get("USER", "")
    if user:
        pats += [rf"(?<![\w.-])/(?:[^/\s]+/)*{re.escape(user)}/", rf"(?<![\w.-]){re.escape(user)}@"]
    host = socket.gethostname().split(".")[0]
    if host:
        pats.append(rf"\b{re.escape(host)}\b")
    return re.compile("|".join(pats))

# Each evidence label, by its attribute value and the words a reader sees.
LABELS = {"stock": "stock", "test-client-only": "test client only", "estimate": "estimate", "failed": "failed", "not-tested": "not tested"}
CLAIM = re.compile(r"<(\w+)\b[^>]*\bdata-evidence=\"([^\"]*)\"[^>]*>(.*?)</\1>", re.S)
SHOWN = re.compile(r'<span class="label">(.*?)</span>', re.S)
FUTURE = re.compile(r"\b(?:we|you|they|it|i|this|that|he|she)\s+(?:will|shall)\b|\b(?:we|you|they|it|i)'ll\b|\bgoing to\b", re.I)
KIND = re.compile(r'data-case-kind="?(\w+)')
QUIET = re.compile(r"<(pre|code|blockquote|style|script)\b.*?</\1>", re.S | re.I)
ASK = re.compile(r'<section class="ask".*?</section>', re.S)

def words(fragment):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", " ", fragment))).strip()

def labels(page):
    hits = []
    for m in CLAIM.finditer(page):
        shown = SHOWN.search(m.group(3))
        if LABELS.get(m.group(2)) is None or not shown or words(shown.group(1)) != LABELS[m.group(2)]:
            hits.append(f"claim {words(SHOWN.sub('', m.group(3)))[:80]}: its label {m.group(2)} and the words a reader sees disagree")
    return hits

def tense(page):
    kind = KIND.search(page)
    if not kind:
        return []
    text = QUIET.sub(" ", DATA.sub("data:,", page))
    if kind.group(1) == "pitch":
        text = ASK.sub(" ", text)
    return [f"future tense outside a pitch's ask: {s[:120]}" for s in re.split(r"(?<=[.!?])\s+", words(text)) if FUTURE.search(s)]

# A data: link in any quoting, with its tag, so the download name can be read.
TAG = re.compile(r"<[^>]*\bdata:[^>]*>")
DATA = re.compile(r"""data:([^,'"\s>]*),([^'"\s>]*)""")
NAME = re.compile(r"""\bdownload\s*=\s*["']?([^"'\s>]+)""")

def decoded(meta, raw):
    """The bytes a data: link holds, or None when they will not decode."""
    if not meta.endswith(";base64"):
        return urllib.parse.unquote_to_bytes(raw)
    try:
        return base64.b64decode(raw, validate=True)
    except ValueError:
        return None  # mutant-ok delete: a function with no return gives None too

def scan(page):
    pat, hits = patterns(), []
    for tag in TAG.finditer(page):
        name = NAME.search(tag.group(0))
        what = f"download {name.group(1)}" if name else "an inline file"
        for m in DATA.finditer(tag.group(0)):
            if m.group(1).startswith("image/"):
                continue  # pixels, not text: build.py shrinks every image through ImageMagick
            data = decoded(m.group(1), m.group(2))
            if data is None:
                hits.append(f"{what}: will not decode, so it cannot be checked")
                continue
            for n, line in enumerate(data.decode("utf-8", errors="replace").splitlines(), 1):
                if pat.search(line):
                    hits.append(f"{what}, line {n}: {line.strip()[:120]}")
    text = html.unescape(DATA.sub("data:,", page))
    for n, line in enumerate(text.splitlines(), 1):
        if pat.search(line):
            hits.append(f"line {n}: {line.strip()[:120]}")
    return hits + labels(page) + tense(page)

def read(path):
    """The file's text: a PDF through pdftotext, any other file as it is."""
    if not path.lower().endswith(".pdf"):
        return open(path, encoding="utf-8").read()
    if not shutil.which("pdftotext"):
        sys.exit(f"case-file check: {path} is a PDF and pdftotext is missing, so it cannot be checked")
    try:
        return subprocess.run(["pdftotext", "-layout", path, "-"], check=True, capture_output=True, timeout=60).stdout.decode("utf-8", "replace")
    except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
        sys.exit(f"case-file check: pdftotext could not read {path}, so it cannot be checked")

# A member past this is refused unread, so a zip bomb cannot fill memory.
LIMIT = 64 << 20

def bundle(path):
    """Every hit in a zip's members, each named by its member."""
    hits = []
    with zipfile.ZipFile(path) as z, tempfile.TemporaryDirectory() as tmp:
        for name in z.namelist():
            with z.open(name) as m:
                data = m.read(LIMIT + 1)
            if len(data) > LIMIT:
                hits.append(f"{name}: over the {LIMIT >> 20} MiB check limit, so it cannot be checked")
                continue
            if name.lower().endswith(".pdf"):
                out = os.path.join(tmp, "member.pdf")
                open(out, "wb").write(data)
                text = read(out)
            else:
                text = data.decode("utf-8", errors="replace")
            hits += [f"{name}: {h}" for h in scan(text)]
    return hits

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)  # mutant-ok delete: a message to a person, no behaviour
    hits = bundle(sys.argv[1]) if sys.argv[1].lower().endswith(".zip") else scan(read(sys.argv[1]))
    if hits:
        print("case-file check: fix each of these before it leaves. Name this machine by its role, a label as its attribute says, and the past by the past tense:")  # mutant-ok delete: a message to a person, no behaviour
        print("\n".join("  " + h for h in hits))
        sys.exit(1)
    print("case-file check: clean")  # mutant-ok delete: a message to a person, no behaviour

if __name__ == "__main__":
    main()
