#!/usr/bin/env python3
"""Open a Markdown file the user must read or fill in as a page in the browser.

Usage: page.py <file.md> [--timeout SECONDS]

The page shows the file as it stands, with a control for each part the user
answers:

  a ```text block            editable text           (text.N)
  a "- [ ] approve" line     a box to tick           (approve.N)
  a "- [x] <label>" line     a box to tick, labelled (box.N)
  a "![name](chart.svg)" line the chart drawn inline, beside the file
  a "1. [ ] check" line      one box per mark        (mark.N: x, ~, -, or blank)
  a "notes:" or "- TAG:" line a line of text         (field.N)
  each ```text block        a comment box under it  (comment.N)
  "- ( ) option" lines       one choice per run of them (choice.N)
  the end of the page        a comment box           (note)
  two or more approve boxes  "approve all" beside Done, ticking every one (approve_all)

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
import os
import re
import subprocess
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
button{font-size:1.1rem;padding:.4rem 1.2rem}
.chart{margin-bottom:2rem;overflow-x:auto}
.chart svg{max-width:100%;height:auto;cursor:zoom-in;background:#fff}
p.text{margin:.6rem 0}
code{background:#8882;padding:0 .25rem;border-radius:3px}
.card{border:1px solid #8886;border-radius:8px;padding:.7rem 1rem;margin:.8rem 0}
.card .act{font-weight:bold}
.card .exp{margin:.2rem 0 .5rem}
.card .meta{font-size:.85rem;opacity:.75;margin:.2rem 0}
.marks label{margin-right:1rem}
.card input[type=text]{width:100%}
details{margin:.6rem 0}
summary{cursor:pointer;opacity:.85}
details.quick label{display:block;margin:.2rem 0}"""
# Each click zooms a chart to 2x, then 3x the window width, then back to fit.
ZOOM = """function zoom(c){const s=c.querySelector("svg"),n=(+c.dataset.z||1)%3+1;c.dataset.z=n;
s.style.maxWidth=n>1?"none":"";s.style.width=n>1?c.clientWidth*n+"px":""}"""
CHECK = re.compile(r"^(\d+\. )\[(.)\] (.*)$")
FIELD = re.compile(r"^(\s*(?:notes|- [A-Z]+)):\s?(.*)$")
APPROVE = re.compile(r"^- \[( |x)\] approve$")
CHOICE = re.compile(r"^- \(( |x)\) (.*)$")
BOX = re.compile(r"^- \[( |x)\] (.+)$")
# A chart is an SVG file in the same folder as the page file.
CHART = re.compile(r"^!\[[^\]]*\]\(([^/\\()\s]+\.svg)\)$")


INLINE = re.compile(r"`([^`]+)`|\*\*([^*]+)\*\*|(?<![\w*])\*([^*\s][^*]*)\*(?![\w*])|(?<!\w)_([^_\s][^_]*)_(?!\w)")
LEGEND = re.compile(r"\[(.)\] ([^,.\[]+)")
HEADER = ("signed off:", "proven by:")
META = re.compile(r"^\s+(person|kit):\s*(.*)$")


def inline(text):
    """A line's text as HTML, with Markdown code spans, bold and italics drawn."""
    out, at = [], 0
    for m in INLINE.finditer(text):
        out.append(html.escape(text[at:m.start()]))
        code, bold, em, em2 = m.groups()
        if code is not None:
            out.append(f"<code>{html.escape(code)}</code>")
        elif bold is not None:
            out.append(f"<strong>{html.escape(bold)}</strong>")
        else:
            out.append(f"<em>{html.escape(em or em2)}</em>")
        at = m.end()
    out.append(html.escape(text[at:]))
    return "".join(out)


def legend(parts):
    """The mark labels a "Mark each item: [x] ..., [~] ..." line gives, by mark."""
    for part in parts:
        if part[0] == "line" and part[1].startswith("Mark each item:"):
            return {m: label.strip() for m, label in LEGEND.findall(part[1])}
    return {}


def parse(text, folder):
    """The file as parts: ("line", s), ("block", [lines]), ("approve", ticked),
    ("box", ticked, label), ("chart", line, svg), ("check", prefix, mark, rest),
    ("field", label, value), ("comment",), ("choice", question, picked, option).
    A chart line whose file is missing stays a plain line."""
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
        elif m := BOX.match(line):
            parts.append(("box", m.group(1) == "x", m.group(2)))
        elif (m := CHART.match(line)) and os.path.isfile(svg := os.path.join(folder, m.group(1))):
            with open(svg) as handle:
                parts.append(("chart", line, handle.read()))
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
    labels = legend(parts)
    out = [f"<!doctype html><meta charset=utf-8><title>{e(name)}</title><style>{STYLE}</style><script>{ZOOM}</script>",
           '<form method=post action="/done">']
    card = quick = False
    quick_at = 0
    header = [part[1] for part in parts if part[0] == "line" and part[1].startswith(HEADER)]

    def close():
        nonlocal card, quick
        if quick:
            out.append("</details>")
        if card:
            out.append("</div>")
        card = quick = False

    for part, n in numbered(parts):
        kind = part[0]
        if kind == "line":
            line = part[1]
            if line.startswith("#"):
                close()
                level = min(len(line) - len(line.lstrip("#")), 6)
                out.append(f"<h{level}>{inline(line.lstrip('#').strip())}</h{level}>")
            elif line.startswith("Mark each item:") and labels:
                continue
            elif line.startswith(HEADER):
                # Signed off and proven by fold into one small header, where the first stands.
                if line == header[0]:
                    rows = "".join(f"<p class=text>{inline(h)}</p>" for h in header)
                    out.append(f"<details><summary>Signed off and proven by</summary>{rows}</details>")
            elif line == "quick notes:":
                close()
                quick_at = len(out)
                out.append("<details class=quick><summary>Quick notes: BUG, QUIRK, FRICTION, UGLY, IDEA, RULE, WIP, QUESTION</summary>")
                quick = True
            elif card and (m := META.match(line)):
                out.append(f"<div class=meta>{e(m.group(1))}: {inline(m.group(2))}</div>")
            elif line.strip() == "":
                if card:
                    close()
            elif line not in ("```text", "```"):
                close()
                out.append(f"<p class=text>{inline(line)}</p>")
        elif kind == "block":
            body = "\n".join(part[1])
            out.append(f'<textarea name="text.{n}" rows="{max(3, len(part[1]) + 1)}">{e(body)}</textarea>')
        elif kind == "approve":
            ticked = " checked" if part[1] else ""
            out.append(f'<label><input type=checkbox name="approve.{n}"{ticked}> approve</label>')
        elif kind == "box":
            ticked = " checked" if part[1] else ""
            out.append(f'<label><input type=checkbox name="box.{n}"{ticked}> {inline(part[2])}</label><br>')
        elif kind == "chart":
            out.append(f'<div class=chart onclick="zoom(this)">{part[2]}</div>')
        elif kind == "check":
            # Each item is a card: the action, what to expect, the mark, then its notes.
            close()
            card = True
            action, _, expect = part[3].partition("→")
            radios = "".join(
                f'<label><input type=radio name="mark.{n}" value="{e(m)}"{" checked" if m == part[2] else ""}> '
                f'{e(labels.get(m, f"[{m}]"))}</label>' for m in MARKS)
            out.append(f'<div class=card><div class=act>{e(part[1])}{inline(action.strip())}</div>')
            if expect.strip():
                out.append(f"<div class=exp>→ {inline(expect.strip())}</div>")
            out.append(f"<div class=marks>{radios}</div>")
        elif kind == "field":
            if quick and part[2]:
                # A block holding a note opens, so the note shows.
                out[quick_at] = "<details class=quick open>" + out[quick_at].removeprefix("<details class=quick>")
            out.append(f'<label>{e(part[1].strip().lstrip("- "))}: <input type=text name="field.{n}" value="{e(part[2])}"></label>')
        elif kind == "comment":
            close()
            out.append(f'<textarea name="comment.{n}" placeholder="Comment"></textarea>')
        elif kind == "choice":
            ticked = " checked" if part[2] else ""
            out.append(f'<label><input type=radio name="choice.{part[1]}" value="{e(part[3])}"{ticked}> {inline(part[3])}</label><br>')
    close()
    out.append('<h2>Anything else</h2><textarea name="note" placeholder="Comment"></textarea>')
    # Two or more approve boxes get one more beside Done that ticks them all.
    approve_all = ('<label><input type=checkbox name="approve_all"> approve all</label> '
                   if sum(part[0] == "approve" for part in parts) > 1 else "")
    out.append(f"<p>{approve_all}<button type=submit>Done</button></p></form>")
    return "\n".join(out)


def answered(parts, form):
    """The file's text with the form's answers written in."""
    def got(key, default):
        return form.get(key, [default])[0].replace("\r\n", "\n")

    def line(key, default):
        return got(key, default).replace("\n", " ").strip()

    out = []
    for part, n in numbered(parts):
        kind = part[0]
        if kind in ("line", "chart"):
            out.append(part[1])
        elif kind == "block":
            text = got(f"text.{n}", "\n".join(part[1])).rstrip("\n")
            # Text the user left alone keeps its lines exactly, an empty
            # block and a trailing blank line included.
            # A typed fence line would close the block early on the next read,
            # so it is written back indented, where the parser reads it as text.
            out.extend(part[1] if text == "\n".join(part[1]).rstrip("\n")
                       else [" ```" if typed == "```" else typed for typed in text.split("\n")])
        elif kind == "approve":
            out.append(f"- [{'x' if f'approve.{n}' in form or 'approve_all' in form else ' '}] approve")
        elif kind == "box":
            out.append(f"- [{'x' if f'box.{n}' in form else ' '}] {part[2]}")
        elif kind == "check":
            mark = got(f"mark.{n}", part[2])
            out.append(f"{part[1]}[{mark if mark in MARKS else part[2]}] {part[3]}")
        elif kind == "field":
            value = line(f"field.{n}", part[2])
            out.append(f"{part[1]}:" + (f" {value}" if value else ""))
        elif kind == "comment":
            comment = line(f"comment.{n}", "")
            if comment:
                out.append(f"Comment: {comment}")
        elif kind == "choice":
            chosen = form.get(f"choice.{part[1]}", [None])[0]
            picked = part[2] if chosen is None else chosen == part[3]
            out.append(f"- ({'x' if picked else ' '}) {part[3]}")
    note = line("note", "")
    if note:
        end = len(out) - 1 if out and out[-1] == "" else len(out)
        out[end:end] = ["", "## Anything else", f"Comment: {note}"]
    return "\n".join(out)


def use_desktop_env():
    """Give the browser the desktop session's environment, not this one.

    A session started in a dev shell carries that shell's library and tool
    paths, and a desktop opener such as kde-open crashes loading them. The
    user's systemd session holds the environment the desktop itself started
    with. Where it can't be read, only LD_LIBRARY_PATH is dropped. BROWSER
    is the user's own choice of browser, so it is kept either way.
    """
    browser = os.environ.get("BROWSER")
    try:
        listed = subprocess.run(["systemctl", "--user", "show-environment"],
                                capture_output=True, text=True, timeout=5)
    except (OSError, subprocess.SubprocessError):
        listed = None
    desktop = {}
    if listed is not None and listed.returncode == 0:
        for line in listed.stdout.splitlines():
            key, sep, value = line.partition("=")
            # systemd writes a value holding special characters as $'...';
            # such a value is skipped rather than half-decoded.
            if sep and not value.startswith("$'"):
                desktop[key] = value
    if desktop:
        os.environ.clear()
        os.environ.update(desktop)
    else:
        os.environ.pop("LD_LIBRARY_PATH", None)
    if browser is not None:
        os.environ["BROWSER"] = browser


def serve_form(text, path, on_post, timeout):
    """Serve the page `text` on this machine only and wait for one POST to
    `path`. `on_post` takes the posted body, URL-encoded, and returns nothing.
    Returns False when no answer came before the timeout."""
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
            if self.path != path or not 0 <= size <= LIMIT or done.is_set() or foreign(self.headers):
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
    print(f"page: open {url}", file=sys.stderr, flush=True)
    use_desktop_env()
    if not webbrowser.open(url):
        print(f"page: no browser opened; give the user {url}", file=sys.stderr, flush=True)
    answered_in_time = done.wait(timeout)
    server.shutdown()
    return answered_in_time


def serve(path, timeout):
    with open(path) as handle:
        original = handle.read()
    parts = parse(original, os.path.dirname(os.path.abspath(path)))

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
