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
member by member, each hit named by the member it sits in, a PNG, JPEG, GIF or WebP member by
everything but its pixel data, and a member over
64 MiB is refused unread.
"""
import base64, html, os, re, shutil, socket, subprocess, sys, tempfile, urllib.parse, zipfile, zlib

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

# An image's pixels hold any byte pair by chance, so an image is checked by everything
# except its pixel data: every other PNG chunk, every JPEG segment before the scan, and
# any bytes after the image ends. Each part below is pixels or fixed-size numbers.
PNG_MAGIC, JPEG_MAGIC = b"\x89PNG\r\n\x1a\n", b"\xff\xd8\xff"
PNG_BINARY = (b"IHDR", b"IDAT", b"PLTE", b"tRNS", b"iCCP", b"sRGB", b"gAMA", b"cHRM", b"pHYs", b"bKGD", b"sBIT", b"hIST", b"tIME", b"fdAT", b"fcTL", b"acTL")
JPEG_BINARY = (0xDB, 0xC4, 0xDD, 0xE2) + tuple(range(0xC0, 0xD0))  # tables, frame headers, ICC profile
EMBEDDED = re.compile(rb"\xff\xd8\xff.*?\xff\xd9", re.S)  # an EXIF thumbnail, which is pixels

class Unreadable(Exception):
    pass  # mutant-ok: already pass

def inflate(packed, room):
    """A compressed text field, inflated within room bytes."""
    try:
        z = zlib.decompressobj()
        text = z.decompress(packed, room + 1)
    except zlib.error:
        raise Unreadable("a compressed text field will not inflate")
    if len(text) > room:
        raise Unreadable(f"its text passes the {LIMIT >> 20} MiB check limit")
    return text

def png_text(data):
    out, room, i = [], LIMIT, 8
    while i + 8 <= len(data):
        n, kind = int.from_bytes(data[i:i + 4], "big"), data[i + 4:i + 8]
        body = data[i + 8:i + 8 + n]
        if kind == b"zTXt":
            key, _, rest = body.partition(b"\0")
            body = key + b" " + inflate(rest[1:], room)  # a method byte, then the deflated text
        elif kind == b"iTXt":
            key, _, rest = body.partition(b"\0")
            text = rest[2:].split(b"\0", 2)[-1]  # flag, method, language, translated key
            body = key + b" " + (inflate(text, room) if rest[:1] == b"\1" else text)
        if kind not in PNG_BINARY:
            room -= len(body)
            out.append(body)
        i += 12 + n
        if kind == b"IEND":
            out.append(data[i:])
            break  # mutant-ok delete: the walk then reads the tail it just kept, as more of the same
    return out

def jpeg_text(data):
    out, i = [], 2
    while i + 4 <= len(data) and data[i] == 0xFF:
        mark, n = data[i + 1], int.from_bytes(data[i + 2:i + 4], "big")
        if mark == 0xDA:
            end = data.rfind(b"\xff\xd9")
            out.append(data[end + 2:] if end > i else b"")  # what follows the image's end
            break
        if mark not in JPEG_BINARY:
            out.append(EMBEDDED.sub(b" ", data[i + 4:i + 2 + n]))
        i += 2 + n
    return out

def blocks(data, i):
    """A GIF's data sub-blocks from i, joined, and the index after them."""
    out = []
    while i < len(data) and data[i]:
        out.append(data[i + 1:i + 1 + data[i]])
        i += 1 + data[i]
    return b"".join(out), i + 1

def gif_text(data):
    out, i = [], 13
    if data[10] & 0x80:
        i += 3 << ((data[10] & 7) + 1)  # the global colour table
    while i < len(data):
        if data[i] == 0x3B:
            out.append(data[i + 1:])  # what follows the trailer  # mutant-ok: the trailer byte holds no text
            break
        if data[i] == 0x2C:
            i += 10 + ((3 << ((data[i + 9] & 7) + 1)) if data[i + 9] & 0x80 else 0)
            _, i = blocks(data, i + 1)  # the pixels, after the code size byte
        elif data[i] == 0x21:
            body, i = blocks(data, i + 2)  # a comment, an application's or plain text
            out.append(body)
        else:
            raise ValueError("no GIF block starts here")
    return out

def webp_text(data):
    out, i = [], 12
    while i + 8 <= len(data):
        kind, n = data[i:i + 4], int.from_bytes(data[i + 4:i + 8], "little")
        if kind not in (b"VP8 ", b"VP8L", b"VP8X", b"ALPH", b"ANIM", b"ANMF", b"ICCP"):
            out.append(data[i + 8:i + 8 + n])
        i += 8 + n + (n & 1)
    return out

def metadata(data):
    """An image's text, everything but its pixels, or None when the bytes are no PNG, JPEG, GIF or WebP."""
    if data.startswith(PNG_MAGIC):
        return b"\n".join(png_text(data))
    if data.startswith(JPEG_MAGIC):
        return b"\n".join(jpeg_text(data))
    if data[:6] in (b"GIF87a", b"GIF89a") and len(data) >= 13:
        try:
            return b"\n".join(gif_text(data))
        except (IndexError, ValueError):
            return None  # a cut or odd GIF is read whole, as any other file  # mutant-ok: falling through returns None too
    if data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return b"\n".join(webp_text(data))
    return None  # mutant-ok delete: a function with no return gives None too

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
                try:
                    meta = metadata(data)
                except Unreadable as e:
                    hits.append(f"{name}: {e}, so it cannot be checked")
                    continue
                text = (data if meta is None else meta).decode("utf-8", errors="replace")
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
