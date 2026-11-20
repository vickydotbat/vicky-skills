#!/usr/bin/env python3
"""The language tutor's learner store: words, reviews, mistakes and level, one
folder per language under the folder the tutor_store setting names.

Every skill in this plugin calls this script; it prints JSON on stdout.

    tutor.py add <front> <back>          a card, due now
    tutor.py due [--limit N]             {"items", "left", "message"}
    tutor.py grade <id> again|hard|good|easy
    tutor.py card <id>
    tutor.py ledger add <type> <original> <fix> | ledger list | ledger top [N]
    tutor.py quiz pick [--max N]         recall, then cloze, then choice items
    tutor.py profile set-level <A1..C2> [--line <can-do line>]... | profile show
    tutor.py disagree <text> <note>      keeps a grade the learner disputes

Settings come from TUTOR_LANGUAGE and TUTOR_STORE, which the skills fill from
the plugin's settings. When both are blank, a .language-tutor.json in the
working directory may name them (eval scaffolds use it).
"""
import argparse
import datetime as dt
import json
import math
import os
import re
import sys

LEVELS = ["A1", "A2", "B1", "B2", "C1", "C2"]
RATINGS = {"again": 1, "hard": 2, "good": 3, "easy": 4}
# FSRS-4.5 default weights, from the open-spaced-repetition project's published defaults.
W = [0.4072, 1.1829, 3.1262, 15.4722, 7.2102, 0.5316, 1.0651, 0.0234, 1.616, 0.1544,
     1.0824, 1.9813, 0.0953, 0.2975, 2.2042, 0.2407, 2.9466]
FACTOR, DECAY = 19 / 81, -0.5
RETENTION = 0.9
QUIZ_ERRORS = 4  # recent mistakes a quiz brings back


class Refusal(Exception):
    pass


def now():
    return dt.datetime.now(dt.timezone.utc).replace(microsecond=0)


def iso(t):
    return t.strftime("%Y-%m-%dT%H:%M:%SZ")


def parse(s):
    return dt.datetime.strptime(s, "%Y-%m-%dT%H:%M:%SZ").replace(tzinfo=dt.timezone.utc)


def settings():
    lang = os.environ.get("TUTOR_LANGUAGE", "").strip()
    store = os.environ.get("TUTOR_STORE", "").strip()
    if not lang and not store and os.path.isfile(".language-tutor.json"):
        with open(".language-tutor.json") as f:
            local = json.load(f)
        lang, store = str(local.get("tutor_language", "")).strip(), str(local.get("tutor_store", "")).strip()
    if not lang:
        raise Refusal("No language is set: set the tutor_language setting to the language you are learning. Nothing was stored.")
    if not store:
        raise Refusal("Nothing was stored: set tutor_store to a folder you own, so your history outlives the plugin.")
    return lang, store


class Store:
    def __init__(self, lang, root):
        slug = re.sub(r"[^a-z0-9]+", "-", lang.lower()).strip("-") or "language"
        self.dir = os.path.join(root, slug)

    def path(self, name):
        return os.path.join(self.dir, name)

    def read(self, name, empty):
        try:
            with open(self.path(name)) as f:
                return json.load(f)
        except FileNotFoundError:
            return empty

    def write(self, name, value):
        os.makedirs(self.dir, exist_ok=True)
        tmp = self.path(name + ".tmp")
        with open(tmp, "w") as f:
            json.dump(value, f, ensure_ascii=False, indent=1)
        os.replace(tmp, self.path(name))  # a crash mid-write never truncates months of history

    def lines(self, name):
        try:
            with open(self.path(name)) as f:
                return [json.loads(l) for l in f if l.strip()]
        except FileNotFoundError:
            return []

    def append(self, name, row):
        os.makedirs(self.dir, exist_ok=True)
        with open(self.path(name), "a") as f:
            f.write(json.dumps(row, ensure_ascii=False) + "\n")


def due_cards(store):
    t = now()
    cards = [c for c in store.read("cards.json", []) if parse(c["due"]) <= t]
    return sorted(cards, key=lambda c: c["due"])


def schedule(card, g, t):
    """One FSRS-4.5 step: new stability and difficulty from the grade."""
    if card.get("stability") is None:
        s = W[g - 1]
        d = W[4] - math.exp(W[5] * (g - 1)) + 1
    else:
        elapsed = max((t - parse(card["last_review"])).total_seconds() / 86400, 0)
        s0, d0 = card["stability"], card["difficulty"]
        r = (1 + FACTOR * elapsed / s0) ** DECAY
        d = d0 - W[6] * (g - 3)
        d = W[7] * (W[4] - math.exp(W[5] * 3) + 1) + (1 - W[7]) * d
        if g == 1:
            s = W[11] * d ** -W[12] * ((s0 + 1) ** W[13] - 1) * math.exp(W[14] * (1 - r))
        else:
            bonus = (W[15] if g == 2 else 1) * (W[16] if g == 4 else 1)
            s = s0 * (math.exp(W[8]) * (11 - d) * s0 ** -W[9] * (math.exp(W[10] * (1 - r)) - 1) * bonus + 1)
    d = min(max(d, 1), 10)
    days = s / FACTOR * (RETENTION ** (1 / DECAY) - 1)
    wait = dt.timedelta(minutes=10) if g == 1 else dt.timedelta(days=max(1, round(days)))
    card.update(stability=s, difficulty=d, last_review=iso(t), due=iso(t + wait),
                reps=card.get("reps", 0) + 1, lapses=card.get("lapses", 0) + (g == 1),
                state="relearning" if g == 1 else "review")
    return card


def cmd_add(store, a):
    cards = store.read("cards.json", [])
    cid = "c%d" % (max([int(c["id"][1:]) for c in cards if c["id"][1:].isdigit()] or [0]) + 1)
    card = {"id": cid, "front": a.front, "back": a.back, "due": iso(now()), "state": "new",
            "stability": None, "difficulty": None, "reps": 0, "lapses": 0, "last_review": None}
    store.write("cards.json", cards + [card])
    return card


def cmd_due(store, a):
    cards = due_cards(store)
    shown = cards[: a.limit] if a.limit else cards
    out = {"items": shown, "left": len(cards) - len(shown)}
    if not cards:
        out["message"] = "Nothing is due."
    return out


def find(cards, cid):
    for c in cards:
        if c["id"] == cid:
            return c
    raise Refusal("No card has the id %s." % cid)


def cmd_grade(store, a):
    cards = store.read("cards.json", [])
    t = now()
    card = schedule(find(cards, a.id), RATINGS[a.rating], t)
    store.write("cards.json", cards)
    store.append("reviews.jsonl", {"card": a.id, "rating": a.rating, "at": iso(t)})
    return card


def cmd_card(store, a):
    return find(store.read("cards.json", []), a.id)


def cmd_ledger(store, a):
    if a.action == "add":
        if len(a.rest) != 3:
            raise Refusal("ledger add takes a type, the learner's text and the fix.")
        row = {"date": now().strftime("%Y-%m-%d"), "type": a.rest[0], "original": a.rest[1], "fix": a.rest[2]}
        store.append("ledger.jsonl", row)
        return row
    rows = store.lines("ledger.jsonl")
    if a.action == "list":
        return rows
    n = int(a.rest[0]) if a.rest else 3
    counts = {}
    for r in rows:
        counts[r["type"]] = counts.get(r["type"], 0) + 1
    ranked = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))
    return [{"type": k, "count": v} for k, v in ranked[:n]]


def cmd_quiz(store, a):
    errors = store.lines("ledger.jsonl")[-QUIZ_ERRORS:]
    items = [{"source": "error", "format": "cloze", "type": e["type"], "original": e["original"], "answer": e["fix"]}
             for e in errors][: a.max]
    cards = due_cards(store)[: a.max - len(items)]
    half = (len(cards) + 1) // 2  # recall first, then recognition (Rowland 2014: recall tests teach more)
    items += [{"source": "card", "format": "recall" if i < half else "choice", "id": c["id"],
               "front": c["front"], "answer": c["back"]} for i, c in enumerate(cards)]
    items.sort(key=lambda i: ["recall", "cloze", "choice"].index(i["format"]))
    out = {"items": items}
    if not items:
        out["message"] = "Nothing to quiz: no words are due and no recent mistakes."
    return out


def cmd_profile(store, a):
    if a.action == "set-level":
        if a.level not in LEVELS:
            raise Refusal("A level is one of %s." % ", ".join(LEVELS))
        profile = store.read("profile.json", {})
        profile.update(level=a.level, placed=now().strftime("%Y-%m-%d"), lines=a.line or [])
        store.write("profile.json", profile)
        return profile
    profile = store.read("profile.json", None)
    if not profile:
        raise Refusal("No profile yet: run placement first.")
    return profile


def cmd_disagree(store, a):
    row = {"date": now().strftime("%Y-%m-%d"), "text": a.text, "note": a.note}
    store.append("disagreements.jsonl", row)
    return {"saved": store.path("disagreements.jsonl"), **row}


def main(argv):
    p = argparse.ArgumentParser(prog="tutor.py")
    sub = p.add_subparsers(dest="cmd", required=True)
    s = sub.add_parser("add"); s.add_argument("front"); s.add_argument("back")
    s = sub.add_parser("due"); s.add_argument("--limit", type=int, default=0)
    s = sub.add_parser("grade"); s.add_argument("id"); s.add_argument("rating", choices=list(RATINGS))
    s = sub.add_parser("card"); s.add_argument("id")
    s = sub.add_parser("ledger"); s.add_argument("action", choices=["add", "list", "top"]); s.add_argument("rest", nargs="*")
    s = sub.add_parser("quiz"); s.add_argument("action", choices=["pick"]); s.add_argument("--max", type=int, default=10)
    s = sub.add_parser("profile"); s.add_argument("action", choices=["set-level", "show"])
    s.add_argument("level", nargs="?"); s.add_argument("--line", action="append")
    s = sub.add_parser("disagree"); s.add_argument("text"); s.add_argument("note")
    a = p.parse_args(argv)
    try:
        lang, root = settings()
        result = globals()["cmd_" + a.cmd](Store(lang, root), a)
    except Refusal as e:
        print(e, file=sys.stderr)
        return 3
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
