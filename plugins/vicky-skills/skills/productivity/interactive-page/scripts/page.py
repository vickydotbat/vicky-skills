#!/usr/bin/env python3
"""Open a Markdown file the user must read or fill in as a page in the browser.

Usage: page.py <file.md> [--timeout SECONDS]

The page shows the file as it stands, with a control for each part the user
answers:

  a ```text block            editable text           (text.N)
  a "- [ ] approve" line     a box to tick           (approve.N)
  a "1. [ ] check" line      one box per mark        (mark.N: x, ~, -, or blank)
  a "notes:" or "- TAG:" line a line of text         (field.N)
  each ```text block        a comment box under it  (comment.N)
  "- ( ) option" lines       one choice per run of them (choice.N)
  the end of the page        a comment box           (note)

When the user presses Done, the answers are written back into the file in
its own form, and the script exits 0. A comment lands as a "Comment: ..."
line under its block, the chosen option is marked "(x)", and the comment at
the end lands under a closing "## Anything else" heading. Answers that change nothing leave the file
byte for byte as it was. The page listens on this machine only. With no
answer before the timeout (four hours by default) it exits 2 and the file
stays as it was.
"""
import html
import http.server
import re
import sys
import threading
import urllib.parse
import webbrowser

LIMIT = 1024 * 1024
MARKS = ["x", "~", "-", " "]
STYLE = """:root{color-scheme:light dark}
body{font-family:sans-serif;margin:1.5rem;max-width:60rem}
textarea{width:100%;min-height:4rem;font-family:monospace}
.text{white-space:pre-wrap;margin:.2rem 0}
input[type=text]{width:70%}
button{font-size:1.1rem;padding:.4rem 1.2rem}"""
CHECK = re.compile(r"^(\d+\. )\[(.)\] (.*)$")
FIELD = re.compile(r"^(\s*(?:notes|- [A-Z]+)):\s?(.*)$")
APPROVE = re.compile(r"^- \[( |x)\] approve$")
CHOICE = re.compile(r"^- \(( |x)\) (.*)$")


def parse(text):
    """The file as parts: ("line", s), ("block", [lines]), ("approve", ticked),
    ("check", prefix, mark, rest), ("field", label, value), ("comment",),
    ("choice", question, picked, option)."""
    parts, lines, i, question = [], text.split("\n"), 0, -1
    while i < len(lines):
        line = lines[i]
        if line == "```text":
            end = i + 1
            while end < len(lines) and lines[end] != "```":
                end += 1
            parts.append(("line", line))
            parts.append(("block", lines[i + 1:end]))
            if end < len(lines):
                parts.append(("line", "```"))
            parts.append(("comment",))
            i = end + 1
            continue
        if m := APPROVE.match(line):
            parts.append(("approve", m.group(1) == "x"))
        elif m := CHECK.match(line):
            parts.append(("check", m.group(1), m.group(2), m.group(3)))
        elif m := FIELD.match(line):
            parts.append(("field", m.group(1), m.group(2)))
        elif m := CHOICE.match(line):
            # A run of option lines is one question.
            if not parts or parts[-1][0] != "choice":
                question += 1
            parts.append(("choice", question, m.group(1) == "x", m.group(2)))
        else:
            parts.append(("line", line))
        i += 1
    return parts


def numbered(parts):
    """Each part with the index of its control among parts of its kind."""
    seen = {}
    for part in parts:
        n = seen.get(part[0], 0)
        seen[part[0]] = n + 1
        yield part, n


def page(name, parts):
    e = html.escape
    out = [f"<!doctype html><meta charset=utf-8><title>{e(name)}</title><style>{STYLE}</style>",
           '<form method=post action="/done">']
    for part, n in numbered(parts):
        kind = part[0]
        if kind == "line":
            line = part[1]
            if line.startswith("#"):
                level = min(len(line) - len(line.lstrip("#")), 6)
                out.append(f"<h{level}>{e(line.lstrip('#').strip())}</h{level}>")
            elif line not in ("```text", "```"):
                out.append(f"<div class=text>{e(line)}</div>")
        elif kind == "block":
            body = "\n".join(part[1])
            out.append(f'<textarea name="text.{n}" rows="{max(3, len(part[1]) + 1)}">{e(body)}</textarea>')
        elif kind == "approve":
            ticked = " checked" if part[1] else ""
            out.append(f'<label><input type=checkbox name="approve.{n}"{ticked}> approve</label>')
        elif kind == "check":
            radios = "".join(
                f'<label><input type=radio name="mark.{n}" value="{e(m)}"{" checked" if m == part[2] else ""}>[{e(m)}]</label> '
                for m in MARKS)
            out.append(f"<div>{e(part[1])}{radios}{e(part[3])}</div>")
        elif kind == "field":
            out.append(f'<label>{e(part[1].strip())}: <input type=text name="field.{n}" value="{e(part[2])}"></label><br>')
        elif kind == "comment":
            out.append(f'<textarea name="comment.{n}" placeholder="Comment"></textarea>')
        elif kind == "choice":
            ticked = " checked" if part[2] else ""
            out.append(f'<label><input type=radio name="choice.{part[1]}" value="{e(part[3])}"{ticked}> {e(part[3])}</label><br>')
    out.append('<h2>Anything else</h2><textarea name="note" placeholder="Comment"></textarea>')
    out.append("<p><button type=submit>Done</button></p></form>")
    return "\n".join(out)


def answered(parts, form):
    """The file's text with the form's answers written in."""
    def got(key, default):
        return form.get(key, [default])[0].replace("\r\n", "\n")

    out = []
    for part, n in numbered(parts):
        kind = part[0]
        if kind == "line":
            out.append(part[1])
        elif kind == "block":
            text = got(f"text.{n}", "\n".join(part[1])).rstrip("\n")
            # Text the user left alone keeps its lines exactly, an empty
            # block and a trailing blank line included.
            out.extend(part[1] if text == "\n".join(part[1]).rstrip("\n") else text.split("\n"))
        elif kind == "approve":
            out.append(f"- [{'x' if f'approve.{n}' in form else ' '}] approve")
        elif kind == "check":
            mark = got(f"mark.{n}", part[2])
            out.append(f"{part[1]}[{mark if mark in MARKS else part[2]}] {part[3]}")
        elif kind == "field":
            value = got(f"field.{n}", part[2]).replace("\n", " ").strip()
            out.append(f"{part[1]}:" + (f" {value}" if value else ""))
        elif kind == "comment":
            comment = got(f"comment.{n}", "").replace("\n", " ").strip()
            if comment:
                out.append(f"Comment: {comment}")
        elif kind == "choice":
            chosen = form.get(f"choice.{part[1]}", [None])[0]
            picked = part[2] if chosen is None else chosen == part[3]
            out.append(f"- ({'x' if picked else ' '}) {part[3]}")
    note = got("note", "").replace("\n", " ").strip()
    if note:
        end = len(out) - 1 if out and out[-1] == "" else len(out)
        out[end:end] = ["", "## Anything else", f"Comment: {note}"]
    return "\n".join(out)




def serve_form(text, path, on_post, timeout, tag="page", open_browser=True, limit=LIMIT):
    """Serve the page `text` on this machine only and wait for one POST to
    `path`. `on_post` takes the posted body, URL-encoded, and returns nothing.
    Returns False when no answer came before the timeout. lay-course's
    answer-page.py serves its planning pages through this too."""
    done = threading.Event()
    origin = ""

    def foreign(headers):
        # Any other web page open in the browser can post a form here, and
        # the browser names that page in Origin. Only this page's own posts,
        # and clients that send no Origin, are taken.
        sent = headers.get("Origin")
        return headers.get("Host") != origin.removeprefix("http://") or (sent is not None and sent != origin)

    class Handler(http.server.BaseHTTPRequestHandler):
        def log_message(self, *args):
            pass

        def reply(self, code, body):
            self.send_response(code)
            self.send_header("Content-Type", "text/html; charset=utf-8")
            self.end_headers()
            self.wfile.write(body)

        def do_GET(self):
            self.reply(200, text)

        def do_POST(self):
            size = int(self.headers.get("Content-Length") or 0)
            if self.path != path or size > limit or done.is_set() or foreign(self.headers):
                self.reply(400, b"Not taken.")
                return
            on_post(self.rfile.read(size).decode())
            self.reply(200, b"<!doctype html><meta charset=utf-8><p>Sent. Back to chat.</p>")
            done.set()

    # Bound to loopback: the page answers this machine only.
    server = http.server.HTTPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    origin = f"http://127.0.0.1:{server.server_address[1]}"
    url = origin + "/"
    print(f"{tag}: open {url}", file=sys.stderr, flush=True)
    if open_browser:
        webbrowser.open(url)
    answered_in_time = done.wait(timeout)
    server.shutdown()
    return answered_in_time


def serve(path, timeout):
    with open(path) as handle:
        original = handle.read()
    parts = parse(original)

    def write_back(body):
        new = answered(parts, urllib.parse.parse_qs(body, keep_blank_values=True))
        if new != original:
            with open(path, "w") as handle:
                handle.write(new)

    if not serve_form(page(path, parts).encode(), "/done", write_back, timeout):
        print(f"page: no answer within {timeout} seconds", file=sys.stderr)
        sys.exit(2)


def main(argv):
    args, timeout = list(argv), 4 * 3600.0
    if "--timeout" in args:
        at = args.index("--timeout")
        timeout = float(args[at + 1])
        del args[at:at + 2]
    if len(args) != 1:
        print(__doc__.strip().splitlines()[2], file=sys.stderr)
        sys.exit(2)
    serve(args[0], timeout)


if __name__ == "__main__":
    main(sys.argv[1:])
