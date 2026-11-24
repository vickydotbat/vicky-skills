#!/usr/bin/env python3
"""Read Claude Code session transcripts for a case file, without loading them whole.

  transcripts.py list [--dir D] [--limit N]
      One line per session, newest first: id, start and end (UTC), user turns,
      compactions, title. Small enough to show the user as candidates.
  transcripts.py digest <id> <out> [--dir D]
      Writes the session's user and assistant text, one timestamped line per
      message, skill bodies and tool output left out, to <out>. Prints its size
      and time span, so the agent reads it in windows (grep, awk by time).

--dir defaults to the transcript folders Claude Code keeps for the repo's
main checkout and each of its worktrees, found from the working directory. A compaction trims the agent's memory, never this file.
"""
import argparse, json, os, re, subprocess, sys
from pathlib import Path

# Records Claude Code writes as user turns. Its caveats and re-invocations carry isMeta.
SKIP = ("Base directory for this skill", "<local-command", "<command-")
INJECTED = {"[Request interrupted by user]", "[Request interrupted by user for tool use]"}

def said(t):
    return t and t not in INJECTED and not t.startswith(SKIP)

def slug(path):
    return re.sub(r"[^A-Za-z0-9-]", "-", path)

def default_dirs():
    """The folders of the main checkout and its worktrees, or of the working directory outside a repo."""
    cwd = os.getcwd()
    try:
        common = subprocess.run(["git", "rev-parse", "--path-format=absolute", "--git-common-dir"],
                                capture_output=True, text=True, timeout=30).stdout.strip()
    except (OSError, subprocess.TimeoutExpired):
        common = ""
    root = os.path.dirname(os.path.realpath(common)) if common else cwd
    projects = Path.home() / ".claude" / "projects"
    found = [projects / slug(cwd), projects / slug(root)] + sorted(projects.glob(slug(root) + "--claude-worktrees-*"))
    return [d for i, d in enumerate(found) if d.is_dir() and d not in found[:i]]

def command(t):
    """A typed command's record, '<command-name>/x</command-name>...<command-args>y</command-args>', as '/x y'."""
    name = re.search(r"<command-name>(.*?)</command-name>", t, re.S)
    args = re.search(r"<command-args>(.*?)</command-args>", t, re.S)
    if name:
        said = args.group(1).strip() if args else ""
        return f"{name.group(1).strip()} {said}" if said else ""  # a bare /clear says nothing
    return t


def texts(msg):
    c = (msg.get("message") or {}).get("content")
    if isinstance(c, str):
        return [command(c)]
    if isinstance(c, list):
        return [command(p.get("text", "")) for p in c if isinstance(p, dict) and p.get("type") == "text"]
    return []

def records(path):
    with open(path, encoding="utf-8", errors="replace") as f:
        for line in f:
            try:
                yield json.loads(line)
            except ValueError:
                continue

def spoken(path):
    for r in records(path):
        if r.get("type") not in ("user", "assistant") or r.get("isCompactSummary") or r.get("isMeta"):
            continue
        for t in texts(r):
            t = t.strip()
            if said(t):
                yield r.get("timestamp", "?"), r["type"], t

def summary(path):
    start = end = title = first = None
    turns = boundaries = summaries = 0
    for r in records(path):
        ts = r.get("timestamp")
        if ts:
            start = start or ts
            end = ts
        if r.get("type") == "custom-title":
            title = r.get("customTitle") or title
        elif r.get("type") == "summary" and not title:
            title = r.get("summary")
        if r.get("type") == "system" and r.get("subtype") == "compact_boundary":
            boundaries += 1
        elif r.get("isCompactSummary"):
            summaries += 1
        elif r.get("type") == "user" and not r.get("isMeta"):
            for t in texts(r):
                t = t.strip()
                if said(t):
                    turns += 1
                    first = first or t
    name = (title or first or "").replace("\n", " ")[:90]
    return start, end, turns, boundaries or summaries, name

def main():
    ap = argparse.ArgumentParser()
    sub = ap.add_subparsers(dest="cmd", required=True)
    l = sub.add_parser("list"); l.add_argument("--dir"); l.add_argument("--limit", type=int, default=15)
    d = sub.add_parser("digest"); d.add_argument("id"); d.add_argument("out"); d.add_argument("--dir")
    a = ap.parse_args()
    folders = [Path(a.dir)] if a.dir else default_dirs()
    folders = [f for f in folders if f.is_dir()]
    if not folders:
        sys.exit(f"transcripts: no transcript folder {a.dir or 'for ' + os.getcwd()}")
    if a.cmd == "list":
        shown = 0
        sessions = [p for f in folders for p in f.glob("*.jsonl")]
        for p in sorted(sessions, key=lambda p: p.stat().st_mtime, reverse=True):
            if shown >= a.limit:
                break
            s, e, n, c, name = summary(p)
            if n:
                shown += 1
                print(f"{p.stem}  {(s or '?')[:16]} to {(e or '?')[:16]}  turns={n} compactions={c}  {name}")
        return
    path = next((f / f"{a.id}.jsonl" for f in folders if (f / f"{a.id}.jsonl").is_file()), None)
    if "/" in a.id or a.id.startswith(".") or not path:
        sys.exit(f"transcripts: no session {a.id}")
    out = Path(a.out); out.parent.mkdir(parents=True, exist_ok=True)
    n = 0; first = last = None
    with open(out, "w", encoding="utf-8") as f:
        for ts, who, t in spoken(path):
            f.write(f"{ts} {who}: {' '.join(t.split())}\n")
            n += 1; first = first or ts; last = ts
    print(f"digest: {out} lines={n} bytes={out.stat().st_size} from {first} to {last}")

if __name__ == "__main__":
    main()
