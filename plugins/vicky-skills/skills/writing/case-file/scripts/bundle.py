#!/usr/bin/env python3
"""Bundle a case file into one zip: a README, the page in every format, and its files.

Usage: bundle.py <page.html> <files-folder> <out-folder> --readme README.md

The PDF is the case file a reader opens first. The HTML ships beside it for
what a PDF cannot do (folded files, download links), and the Markdown for a
diff. The document's source ships too: the case folder's sections/ under
source/, so a reader can rebuild or quote it.

The zip is named <name>-<YYYY-MM-DD>-<HHMM>.zip for the page's name and the
minute it was made. A PDF or Markdown older than the page stops the bundle
before any zip is written, so one zip never mixes two builds. It unpacks into one <name>/ folder: README.md, the page,
the PDF and Markdown built beside it, and every file under files-folder under
files/. One zip per case: once the new zip is written, every earlier zip of
the same case in out-folder is deleted, and any other file is left alone. The
tracker keeps its own copy of each zip it was given.
"""
import argparse, datetime, os, re, sys, zipfile

def earlier(name, stem):
    """True for a zip this script made for the case, in today's or the old naming."""
    return re.fullmatch(re.escape(stem) + r"-(\d{4}-\d\d-\d\d-\d{4}(-\d+)?|\d{8}-\d{6}-\d+)\.zip", name) is not None

def new_zip(out, stem):
    """Open a zip name no earlier bundle holds, created exclusively."""
    stamp = datetime.datetime.now().strftime("%Y-%m-%d-%H%M")
    for n in range(1, 1000):
        path = os.path.join(out, f"{stem}-{stamp}.zip" if n == 1 else f"{stem}-{stamp}-{n}.zip")
        try:
            return path, open(path, "xb")
        except FileExistsError:
            pass  # mutant-ok delete: already pass
    sys.exit("case-file bundle: no free zip name in " + out)  # mutant-ok delete: a message to a person, no behaviour

def main():
    p = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    p.add_argument("page"); p.add_argument("files"); p.add_argument("out")
    p.add_argument("--readme", required=True)
    a = p.parse_args()
    os.makedirs(a.out, exist_ok=True)
    stem = os.path.splitext(os.path.basename(a.page))[0]
    for ext in (".pdf", ".md"):
        built = os.path.splitext(a.page)[0] + ext
        if os.path.isfile(built) and os.path.getmtime(built) < os.path.getmtime(a.page):
            sys.exit(f"case-file bundle: {built} is older than {a.page}: rebuild every format before bundling")
    path, f = new_zip(a.out, stem)
    with f, zipfile.ZipFile(f, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(a.readme, f"{stem}/README.md")
        for ext in (".html", ".pdf", ".md"):
            built = os.path.splitext(a.page)[0] + ext
            if os.path.isfile(built):
                z.write(built, f"{stem}/{stem}{ext}")
        sections = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(a.page))), "sections")
        for d, _, names in os.walk(sections):
            for name in sorted(names):
                full = os.path.join(d, name)
                z.write(full, os.path.join(stem, "source", "sections", os.path.relpath(full, sections)))
        for d, _, names in os.walk(a.files):
            for name in sorted(names):
                full = os.path.join(d, name)
                z.write(full, os.path.join(stem, "files", os.path.relpath(full, a.files)))
    print(f"bundled: {path}")  # mutant-ok delete: a message to a person, no behaviour
    for name in sorted(os.listdir(a.out)):
        if name != os.path.basename(path) and earlier(name, stem):
            os.remove(os.path.join(a.out, name))
            print(f"removed: {name}")  # mutant-ok delete: a message to a person, no behaviour

if __name__ == "__main__":
    main()
