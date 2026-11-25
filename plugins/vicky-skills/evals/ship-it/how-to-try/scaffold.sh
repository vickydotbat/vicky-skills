#!/usr/bin/env bash
# A command-line tool whose word count missed the last word of a line with no
# newline at the end, and a branch that fixes it, with a test.
set -eu
git init -q -b main .
mkdir -p tests
printf 'import sys\ndef count(text):\n    return text.count(" ") + text.count("\\n")\nif __name__ == "__main__":\n    print(count(sys.stdin.read()))\n' > wc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m start
git switch -q -c last-word
printf 'import sys\ndef count(text):\n    return len(text.split())\nif __name__ == "__main__":\n    print(count(sys.stdin.read()))\n' > wc.py
printf 'import unittest\nfrom wc import count\nclass T(unittest.TestCase):\n    def test_no_newline(self):\n        self.assertEqual(count("a b"), 2)\n' > tests/test_wc.py
git add -A && git -c user.name=eval -c user.email=eval@example.invalid commit -q -m "Count the last word of a line with no newline"
