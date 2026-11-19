#!/usr/bin/env python3
"""Build one self-contained case file, as HTML and optionally PDF and Markdown.

Usage: build.py <case folder or template.html> <page.html> [--formats html,pdf,md]

A case folder's page is every sections/*.html file in it, in file name order,
with marker paths relative to the case folder. A single template is the page's
body, with paths relative to the template. Either is written as HTML. The PDF
and the Markdown are written beside the page under its name, the PDF printed
from the HTML by a headless browser so the two always match. A page that names
this machine, an unknown format or a missing browser stops the build before
any file is written.

The source names one kind, research, demonstration or pitch, on a
<!-- KIND <kind> --> line. Dated markers, each on its own line, with a time
such as 2026-11-19T14:05+00:00 that carries its zone:
  <!-- CLAIM label | when | source | text -->  a claim with its evidence label
  <!-- EVENT when | text -->                  an event for the timeline
  <!-- QUOTE when | who | text -->            a quote the user approved
  <!-- STEP command | expected result -->     a step that reproduces the effort
  <!-- ASK --> ... <!-- END ASK -->           a pitch's ask, the one part in the present or future
Every claim, event and quote goes on a timeline, oldest first, where a
<!-- TIMELINE --> line stands or else at the end. A claim, event or quote with
no time stops the build. Markers, each on its own line, with paths relative to the template:
  <!-- IMG path | caption -->  an image, shrunk to 720 px wide, caption under it
  <!-- FILE path -->           a text file shown whole, with a download link
  <!-- BIN path -->            a binary file shown as hex, with a download link
Everything goes inline, so the page loads nothing beside itself. A marker
naming a missing file stops the build, and no page is written.
"""
import argparse, base64, datetime, glob, html, os, re, shutil, subprocess, sys, tempfile
from html.parser import HTMLParser

import check  # beside this script, on the path Python gives a script

WIDTH = 720
# A case file goes out as one page: a file past this would make it too big to send or open.
MAX_BYTES = 20 * 1024 * 1024
# ImageMagick reads an image's declared size, so a small bomb file can still ask for gigabytes.
LIMITS = ["-limit", "width", "16KP", "-limit", "height", "16KP", "-limit", "memory", "256MiB", "-limit", "disk", "1GiB"]
MARKER_LINE = re.compile(r"^[ \t]*<!--\s*(IMG|FILE|BIN)\s+(.+?)\s*-->[ \t]*$", re.M)
KIND_LINE = re.compile(r"^[ \t]*<!--\s*KIND\s+(\S*)\s*-->[ \t]*\n?", re.M)
KINDS = ("research", "demonstration", "pitch")
DATED_LINE = re.compile(r"^[ \t]*<!--\s*(CLAIM|EVENT|QUOTE|STEP)\s+(.*?)\s*-->[ \t]*$", re.M)
ASK_LINE = re.compile(r"^[ \t]*<!--\s*(END )?ASK\s*-->[ \t]*$", re.M)
TIMELINE_LINE = re.compile(r"^[ \t]*<!--\s*TIMELINE\s*-->[ \t]*$", re.M)
LABELS = check.LABELS
# A reboot or a crash wipes these, and a case file grows across sessions.
VOLATILE = ("/tmp", "/var/tmp", "/dev/shm", "/run/user")
STYLE = """body{font:16px/1.5 system-ui,sans-serif;max-width:52rem;margin:2rem auto;padding:0 1rem;color:#1b1b1b;background:#fff}
@media(prefers-color-scheme:dark){body{color:#e8e8e8;background:#161616}pre{background:#222!important}}
figure{margin:1.5rem 0}figure img{max-width:100%;height:auto}figcaption{font-size:.9rem;opacity:.8}
pre{background:#f4f4f4;padding:.75rem;overflow:auto;font-size:.85rem}a.download{font-size:.9rem}"""


def fail(msg):
    sys.exit(f"case-file build: {msg}")  # mutant-ok delete: a message to a person, no behaviour


def shrink(path, label):
    """The image as JPEG bytes at most WIDTH pixels wide."""
    # shortcut: calls convert, which ImageMagick 6 and 7 both ship; switch to magick once 6 is gone.
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "img.jpg")
        try:
            subprocess.run(["convert", *LIMITS, path + "[0]", "-resize", f"{WIDTH}x>", "-quality", "85", out],
                           check=True, capture_output=True, timeout=60)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired):
            fail(f"marker {label}: ImageMagick could not shrink it within its limits")
        return open(out, "rb").read()


def download(name, data):
    b64 = base64.b64encode(data).decode()
    return f'<a class=download href="data:application/octet-stream;base64,{b64}" download="{html.escape(name)}">Download {html.escape(name)}</a>'


def render(kind, arg, base):
    path_text, _, caption = arg.partition("|")
    rel = path_text.strip()
    path = os.path.join(base, rel)
    if os.path.commonpath([os.path.realpath(path), os.path.realpath(base)]) != os.path.realpath(base):
        fail(f"marker {kind} {rel}: outside the template's folder")
    if os.path.isfile(path) and os.path.getsize(path) > MAX_BYTES:
        fail(f"marker {kind} {rel}: too big, over {MAX_BYTES // 1048576} MB")
    if not os.path.isfile(path):
        fail(f"marker {kind} {rel}: no such file")  # mutant-ok delete: open() below then stops the build naming the same path
    name = os.path.basename(rel)
    if kind == "IMG":
        b64 = base64.b64encode(shrink(path, f"{kind} {rel}")).decode()
        cap = html.escape(caption.strip())
        return f'<figure><img src="data:image/jpeg;base64,{b64}" alt="{cap}"><figcaption>{cap}</figcaption></figure>'
    data = open(path, "rb").read()
    if kind == "FILE":
        shown = html.escape(data.decode("utf-8", errors="replace"))
    else:
        shown = "\n".join(" ".join(f"{b:02x}" for b in data[i:i + 16]) for i in range(0, len(data), 16))
    return f"<p><strong>{html.escape(name)}</strong></p><pre>{shown}</pre><p>{download(name, data)}</p>"


def lasting(path):
    """Stop the build when the case file sits in a folder a reboot wipes, outside a .case-files folder."""
    real = os.path.realpath(path)
    if ".case-files" in real.split(os.sep):
        return
    roots = VOLATILE + ((os.environ["TMPDIR"],) if os.environ.get("TMPDIR") else ())
    for root in roots:
        r = os.path.realpath(root)
        if real == r or real.startswith(r.rstrip(os.sep) + os.sep):
            fail(f"{path} is in the scratch folder {root}, which a reboot wipes: keep a case file under .case-files/<name>/ at the repo's root")


def kind_of(text):
    """The page's one kind, read from its KIND marker."""
    kinds = [m.group(1) for m in KIND_LINE.finditer(text)]
    if len(kinds) != 1 or kinds[0] not in KINDS:
        named = ", ".join(kinds) or "none"  # mutant-ok: the words of a message, no behaviour
        fail(f"a case file names exactly one kind, research, demonstration or pitch, in a <!-- KIND <kind> --> line; this one names {named}")
    return kinds[0]


def source(src):
    """The page's source text and the folder its marker paths start from."""
    if not os.path.isdir(src):
        return open(src, encoding="utf-8").read(), os.path.dirname(os.path.abspath(src))
    files = sorted(glob.glob(os.path.join(src, "sections", "*.html")))
    if not files:
        fail(f"{src} has no section files: put the page's parts in {os.path.join(src, 'sections')}/*.html")
    return "".join(open(f, encoding="utf-8").read().rstrip("\n") + "\n" for f in files), os.path.abspath(src)


def when(text, what):
    """The time a marker names, with its zone, or a stop naming the marker."""
    raw = re.sub(r"\s+([+-]\d\d:?\d\d|Z)$", r"\1", text.strip())
    try:
        t = datetime.datetime.fromisoformat(raw.replace(" ", "T", 1))
    except ValueError:
        t = None
    if t is None or t.tzinfo is None:
        fail(f"{what}: needs its date and time with a zone, such as 2026-11-19T14:05+00:00, and has {text.strip() or 'none'}")  # mutant-ok: the words of a message, no behaviour
    return t, f"{t:%Y-%m-%d %H:%M} {t.isoformat()[-6:]}"


def dated(text, events):
    """Each dated marker as HTML, with each claim, event and quote kept for the timeline."""
    def one(m):
        kind, parts = m.group(1), [s.strip() for s in m.group(2).split("|")]
        e = html.escape
        if kind == "STEP":
            cmd, exp = (parts + [""])[:2]
            if not exp:
                fail(f"marker STEP {cmd}: needs its expected result after a |")
            return f'<div class="step"><pre><code>{e(cmd)}</code></pre><p>Expected: {e(" | ".join(parts[1:]))}</p></div>'
        need = {"CLAIM": 4, "EVENT": 2, "QUOTE": 3}[kind]
        if len(parts) < need:
            fail(f"marker {kind} {m.group(2)}: needs {need} parts split by |")
        body = " | ".join(parts[need - 1:])
        if kind == "CLAIM":
            label, stamp, src = parts[:3]
            if label not in LABELS:
                fail(f"claim {body}: its label {label or 'none'} is not one of {', '.join(LABELS)}")  # mutant-ok: the words of a message, no behaviour
            t, shown = when(stamp, f"claim {body}")
            events.append((t, shown, body))
            return (f'<p class="claim" data-evidence="{label}" data-when="{t.isoformat()}" data-source="{e(src)}">'
                    f'<time datetime="{t.isoformat()}">{shown}</time> {e(body)} <span class="label">{LABELS[label]}</span>'
                    f' <small class="source">Source: {e(src)}</small></p>')
        if kind == "EVENT":
            t, shown = when(parts[0], f"event {body}")
            events.append((t, shown, body))
            return f'<p class="event" data-when="{t.isoformat()}"><time datetime="{t.isoformat()}">{shown}</time> {e(body)}</p>'
        t, shown = when(parts[0], f"quote {body}")
        events.append((t, shown, f"{parts[1]}: {body}"))
        return (f'<blockquote class="quote" data-when="{t.isoformat()}"><p>{e(body)}</p>'
                f'<footer>{e(parts[1])}, <time datetime="{t.isoformat()}">{shown}</time></footer></blockquote>')
    return DATED_LINE.sub(one, text)


def timeline(events):
    rows = "".join(f'<li><time datetime="{t.isoformat()}">{shown}</time> {html.escape(text)}</li>'
                   for t, shown, text in sorted(events, key=lambda ev: ev[0]))
    return f'<section data-timeline><h2>Timeline</h2><ol>{rows}</ol></section>\n' if events else ""


def page(src):
    """The whole page as HTML, unchecked."""
    lasting(src)
    text, base = source(src)
    body = MARKER_LINE.sub(lambda m: render(m.group(1), m.group(2), base), text)
    kind = kind_of(body)
    body = KIND_LINE.sub("", body)
    events = []
    body = dated(body, events)
    body = ASK_LINE.sub(lambda m: "</section>" if m.group(1) else '<section class="ask" data-ask>', body)
    line = timeline(events)
    body = TIMELINE_LINE.sub(lambda m: line, body, count=1) if TIMELINE_LINE.search(body) else body + line
    ask = "<p class=ask-note>This case file asks you to act.</p>\n" if kind == "pitch" else ""
    return (f"<!doctype html><html lang=en data-case-kind={kind}><meta charset=utf-8><meta name=viewport content='width=device-width'>"
            f"<style>{STYLE}</style><body data-case-kind=\"{kind}\">\n<p class=kind>Kind: {kind}</p>\n{ask}{body}</body></html>\n")


class Markdown(HTMLParser):
    """The page's text as Markdown: headings, paragraphs, lists, code and links, images by caption."""
    def __init__(self):
        super().__init__(convert_charrefs=True)
        self.out, self.pre, self.href, self.skip, self.quote = [], 0, None, 0, 0

    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if tag in ("style", "script"):
            self.skip += 1
        elif re.fullmatch(r"h[1-6]", tag):
            self.out.append("\n\n" + "#" * int(tag[1]) + " ")
        elif tag == "blockquote":
            self.quote += 1
            self.out.append("\n\n")
        elif self.quote and tag in ("p", "footer"):
            self.out.append("\n> ")
        elif tag in ("p", "figure", "section", "ul", "ol"):
            self.out.append("\n\n")
        elif tag == "li":
            self.out.append("\n- ")
        elif tag == "pre":
            self.pre += 1
            self.out.append("\n\n```\n")
        elif tag == "img":
            self.out.append(f"[image: {a.get('alt') or 'no caption'}]")
        elif tag == "a" and not (a.get("href") or "").startswith("data:"):
            self.href = a.get("href")
            self.out.append("[")

    def handle_endtag(self, tag):
        if tag in ("style", "script"):
            self.skip -= 1
        elif tag == "blockquote":
            self.quote -= 1
        elif tag == "pre":
            self.pre -= 1
            self.out.append("\n```\n\n")
        elif tag == "a" and self.href is not None:
            self.out.append(f"]({self.href})")
            self.href = None

    def handle_data(self, data):
        if not self.skip:
            self.out.append(data if self.pre else re.sub(r"\s+", " ", data))

    def text(self):
        return re.sub(r"\n{3,}", "\n\n", re.sub(r"[ \t]+\n", "\n", "".join(self.out))).strip() + "\n"


def markdown(page_html):
    md = Markdown()
    md.feed(page_html)
    return md.text()


def browser():
    """The headless browser that prints the PDF: CASE_FILE_BROWSER, or the first Chromium on PATH."""
    if os.environ.get("CASE_FILE_BROWSER"):
        return os.environ["CASE_FILE_BROWSER"]
    for name in ("chromium", "chromium-browser", "google-chrome", "google-chrome-stable"):
        if shutil.which(name):
            return shutil.which(name)
    fail("a PDF needs a headless browser: no chromium, chromium-browser or google-chrome on PATH, and CASE_FILE_BROWSER is unset")


def pdf(page_html, run):
    """The PDF the browser prints from the page, as bytes."""
    with tempfile.TemporaryDirectory() as tmp:
        src, out = os.path.join(tmp, "page.html"), os.path.join(tmp, "page.pdf")
        open(src, "w", encoding="utf-8").write(page_html)
        try:
            subprocess.run([run, "--headless", "--disable-gpu", "--no-sandbox", f"--user-data-dir={os.path.join(tmp, 'profile')}",
                            "--no-pdf-header-footer", f"--print-to-pdf={out}", "file://" + src],
                           check=True, capture_output=True, timeout=120)
        except (subprocess.CalledProcessError, subprocess.TimeoutExpired, OSError):
            fail(f"the browser {run} could not print the PDF")
        if not os.path.isfile(out):
            fail(f"the browser {run} printed no PDF")
        return open(out, "rb").read()


FORMATS = ("html", "pdf", "md")


def main():
    ap = argparse.ArgumentParser(usage=__doc__)
    ap.add_argument("source")
    ap.add_argument("page")
    ap.add_argument("--formats", default="html")
    args = ap.parse_args()
    formats = [f.strip() for f in args.formats.split(",") if f.strip()]
    unknown = [f for f in formats if f not in FORMATS]
    if unknown:
        fail(f"unknown format {', '.join(unknown)}: the build writes html, pdf and md")
    run = browser() if "pdf" in formats else None
    built = page(args.source)
    md = markdown(built)
    for what, text in (("the page", built), ("the Markdown", md)):
        hits = check.scan(text)
        if hits:
            fail(f"{what} names this machine. Name each by its role:\n" + "\n".join("  " + h for h in hits))
    outputs = {"html": built.encode(), "md": md.encode()}
    if run:
        outputs["pdf"] = pdf(built, run)  # printed from the checked page, before any file is written
    stem = re.sub(r"\.html?$", "", args.page)
    os.makedirs(os.path.dirname(os.path.abspath(args.page)), exist_ok=True)
    for f in formats:
        path = args.page if f == "html" else f"{stem}.{f}"
        with open(path, "wb") as out:
            out.write(outputs[f])
        print(f"built: {path}")  # mutant-ok delete: a message to a person, no behaviour


if __name__ == "__main__":
    main()
