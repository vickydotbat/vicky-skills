#!/usr/bin/env python3
"""Refuse a case file that leaks this machine, before it leaves.

Usage: check.py <page.html>

Scans the page's text, and every data: download decoded, for loose-lips'
"This machine" kinds: home folders, the nix store, scratch folders under
/tmp, this user's name in a path or address, and this host's name. Exits 1
naming each hit's line or download, 0 when the page is clean.
"""
import base64, os, re, socket, sys, urllib.parse

def patterns():
    pats = [r"(?<![\w./-])/(home|Users)/[^/\s\"'<>]+/", r"/nix/store/", r"(?<![\w./-])/tmp/[^\s\"'<>]+"]  # local-path-ok: the patterns the check looks for
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

DOWNLOAD = re.compile(r'href="data:([^";,]*)(;base64)?,([^"]*)"[^>]*?download="([^"]*)"')

def scan(page):
    pat, hits = patterns(), []
    for m in DOWNLOAD.finditer(page):
        raw = m.group(3)
        data = base64.b64decode(raw) if m.group(2) else urllib.parse.unquote(raw).encode()
        for n, line in enumerate(data.decode("utf-8", errors="replace").splitlines(), 1):
            if pat.search(line):
                hits.append(f"download {m.group(4)}, line {n}: {line.strip()[:120]}")
    text = DOWNLOAD.sub('href="" download', page)
    text = re.sub(r'src="data:[^"]*"', 'src=""', text)
    for n, line in enumerate(text.splitlines(), 1):
        if pat.search(line):
            hits.append(f"line {n}: {line.strip()[:120]}")
    return hits

def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)  # mutant-ok delete: a message to a person, no behaviour
    hits = scan(open(sys.argv[1], encoding="utf-8").read())
    if hits:
        print("case-file check: this page names this machine. Name each by its role:")  # mutant-ok delete: a message to a person, no behaviour
        print("\n".join("  " + h for h in hits))
        sys.exit(1)
    print("case-file check: clean")  # mutant-ok delete: a message to a person, no behaviour

if __name__ == "__main__":
    main()
