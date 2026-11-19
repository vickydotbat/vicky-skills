#!/usr/bin/env python3
"""Bundle a case file into one new zip: a README, the page, and its files.

Usage: bundle.py <page.html> <files-folder> <out-folder> --readme README.md

The zip holds README.md, the page, and every file under files-folder kept in
its folders under files/. It is always a new zip beside any earlier one: the
script never deletes or overwrites, since a tracker or a reader may hold the
earlier bundle.
"""
import argparse, datetime, os, sys, zipfile

def new_zip(out, stem):
    """Open a zip name no earlier bundle holds, created exclusively."""
    stamp = datetime.datetime.now().strftime("%Y%m%d-%H%M%S")
    for n in range(1, 1000):
        path = os.path.join(out, f"{stem}-{stamp}-{n}.zip")
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
    path, f = new_zip(a.out, stem)
    with f, zipfile.ZipFile(f, "w", zipfile.ZIP_DEFLATED) as z:
        z.write(a.readme, "README.md")
        z.write(a.page, os.path.basename(a.page))
        for d, _, names in os.walk(a.files):
            for name in sorted(names):
                full = os.path.join(d, name)
                z.write(full, os.path.join("files", os.path.relpath(full, a.files)))
    print(f"bundled: {path}")  # mutant-ok delete: a message to a person, no behaviour

if __name__ == "__main__":
    main()
