"""The session's scratch folder rule for a page file.

A page goes in `<temp folder>/<session id>`, never loose in the shared temp
folder, since a stray page there is what the scratch rule refuses and what the
next session finds. `loose_page` returns the refusal line for a page path whose
parent is the shared temp folder while the session id is set, else None.
"""
import os
import tempfile


def loose_page(path):
    session = os.environ.get("CLAUDE_CODE_SESSION_ID", "")
    if not session:
        return None
    temp = os.path.realpath(os.environ.get("TMPDIR") or tempfile.gettempdir())
    parent = os.path.realpath(os.path.dirname(os.path.abspath(path)))
    if parent != temp:
        return None
    return f"page file {path} sits loose in the shared temp folder: write it in {os.path.join(temp, session)}/ instead"
