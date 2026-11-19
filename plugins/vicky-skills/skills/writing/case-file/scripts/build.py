#!/usr/bin/env python3
"""Build one self-contained HTML case file from an HTML template.

Usage: build.py <template.html> <page.html>

The template is the page's body, written as HTML. Markers, each on its own line, with paths relative to the template:
  <!-- IMG path | caption -->  an image, shrunk to 720 px wide, caption under it
  <!-- FILE path -->           a text file shown whole, with a download link
  <!-- BIN path -->            a binary file shown as hex, with a download link
Everything goes inline, so the page loads nothing beside itself. A marker
naming a missing file stops the build, and no page is written.
"""
import base64, html, os, re, subprocess, sys, tempfile

WIDTH = 720
# A case file goes out as one page: a file past this would make it too big to send or open.
MAX_BYTES = 20 * 1024 * 1024
# ImageMagick reads an image's declared size, so a small bomb file can still ask for gigabytes.
LIMITS = ["-limit", "width", "16KP", "-limit", "height", "16KP", "-limit", "memory", "256MiB", "-limit", "disk", "1GiB"]
MARKER_LINE = re.compile(r"^[ \t]*<!--\s*(IMG|FILE|BIN)\s+(.+?)\s*-->[ \t]*$", re.M)
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


def build(template):
    base = os.path.dirname(os.path.abspath(template))
    body = MARKER_LINE.sub(lambda m: render(m.group(1), m.group(2), base), open(template, encoding="utf-8").read())
    return (f"<!doctype html><html lang=en><meta charset=utf-8><meta name=viewport content='width=device-width'>"
            f"<style>{STYLE}</style><body>\n{body}</body></html>\n")


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)  # mutant-ok delete: a message to a person, no behaviour
    page = build(sys.argv[1])  # raises before any write, so a failed build leaves no page
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        f.write(page)
    print(f"built: {sys.argv[2]}")  # mutant-ok delete: a message to a person, no behaviour


if __name__ == "__main__":
    main()
