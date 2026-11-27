#!/usr/bin/env python3
"""Antigravity lifecycle hook adapter for vicky-skills.

Translates Antigravity SessionStart, PreInvocation, PreToolUse, PostToolUse, and
Stop payloads into Claude Code hook payloads, loads plugin.json defaults plus
optional $PLUGIN_DATA/config.json into CLAUDE_PLUGIN_OPTION_*, and translates
hook outputs back to Antigravity's JSON contract.
"""
import hashlib
import json
import os
import subprocess
import sys

ARG_MAP = {
    "run_command": ("Bash", {"command": "CommandLine"}),
    "edit_file": ("Edit", {"file_path": "Path", "old_string": "Target", "new_string": "Replacement"}),
    "write_file": ("Write", {"file_path": "Path", "content": "Content"}),
    "invoke_subagent": ("Agent", {"subagent_type": "TypeName", "prompt": "Prompt", "description": "Role"}),
    "read_file": ("Read", {"file_path": "Path"}),
}

BASH_PRE_RULES = (
    (("git", "gh", "tea", "gs", "git-spice"), (
        "pr-guard.sh", "draft-guard.sh", "worktree-place.sh",
        "local-path-guard.sh", "post-body-guard.sh", "push-behind-guard.sh", "shellcheck-guard.sh",
        "rebase-guard.sh", "restack-origin-guard.sh", "git-guard.sh", "red-first-guard.sh",
        "merged-branch-guard.sh", "foreign-post-hint.sh",
    )),
    (("git", "gh", "tea", "gs", "git-spice", "curl", "wget", "release-outside", "outside-read"), ("outside-text-guard.sh",)),
    (("gh", "glab", "tea"), ("publish-guard.sh",)),
    (("advisory.sh", "security-advisories", "gh", "tea", "curl", "wget"), ("advisory-guard.sh",)),
    (("tea",), ("tea-stdin.sh",)),
    (("plane", "tea", "gh"), ("ticket-filing-guard.sh", "plane-block-guard.sh")),
    (("head", "tail", "grep", "cut", "awk", "sed"), ("whole-read-guard.sh",)),
    (("pkill",), ("pkill-guard.sh",)),
    (("claude",), ("eval-tmpdir-guard.sh",)),
    (("gh", "tea", "pulls/", "PullRequest", "merge", "ready"), ("opponent-wait-guard.sh",)),
)

STATIC_PRE_HOOKS = {
    "Read": ("skill-ledger.sh",),
    "Edit": ("approved-test-lock.sh", "adr-scope-hint.sh", "patch-tell-hint.sh"),
    "Write": ("approved-test-lock.sh", "adr-scope-hint.sh", "patch-tell-hint.sh"),
    "Agent": ("review-brief-guard.sh",),
}


def emit(obj):
    print(json.dumps(obj))


def resolve_paths():
    scripts_dir = os.path.dirname(os.path.abspath(__file__))  # mutant-ok delete: only used in fallback
    plugin_root = os.environ.get("PLUGIN_ROOT") or os.environ.get("CLAUDE_PLUGIN_ROOT") or os.path.dirname(scripts_dir)  # mutant-ok: fallback when env unset
    plugin_data = os.environ.get("PLUGIN_DATA") or os.environ.get("CLAUDE_PLUGIN_DATA") or os.path.join(os.path.expanduser("~"), ".gemini", "antigravity", "plugin_data", "vicky-skills")  # mutant-ok: fallback when env unset
    return plugin_root, plugin_data


def resolve_project_dir(cwd):
    if not os.path.isdir(cwd or ""):
        return cwd  # mutant-ok: missing dir returns cwd either way
    try:
        r = subprocess.run(["git", "-C", cwd, "rev-parse", "--show-toplevel"], capture_output=True, text=True, timeout=3)
        if r.returncode == 0:
            return r.stdout.strip()
    except Exception:
        pass  # mutant-ok delete: defensive fallback if git missing or times out
    return cwd


def load_options(plugin_root, plugin_data, env):
    opts = {}
    manifest = os.path.join(plugin_root, ".claude-plugin", "plugin.json")
    if os.path.isfile(manifest):
        try:
            for k, spec in (json.load(open(manifest, "r", encoding="utf-8")).get("userConfig") or {}).items():
                if isinstance(spec, dict):
                    opts[k] = spec.get("default")
        except Exception:
            pass  # mutant-ok delete: ignore malformed manifest
    cfg_path = os.path.join(plugin_data, "config.json")
    if os.path.isfile(cfg_path):
        try:
            user_cfg = json.load(open(cfg_path, "r", encoding="utf-8"))
            if isinstance(user_cfg, dict):
                opts.update(user_cfg)
        except Exception:
            pass  # mutant-ok delete: ignore malformed user config
    for k, v in opts.items():
        env_key = f"CLAUDE_PLUGIN_OPTION_{k.upper()}"
        if env_key not in env and v is not None:
            env[env_key] = ("true" if v else "false") if isinstance(v, bool) else str(v)


def build_env(plugin_root, plugin_data, project_dir, conv_id):
    env = os.environ.copy()
    env["CLAUDE_PLUGIN_ROOT"] = plugin_root
    env["CLAUDE_PLUGIN_DATA"] = plugin_data
    env["CLAUDE_CODE_SESSION_ID"] = conv_id
    env["VICKY_SESSION_ID"] = conv_id
    env["CLAUDE_PROJECT_DIR"] = project_dir
    load_options(plugin_root, plugin_data, env)
    return env


def run_script(scripts_dir, name, claude_json, cwd, env, timeout=20):
    path = os.path.join(scripts_dir, name)
    if not os.path.isfile(path):
        return None, None  # mutant-ok delete: missing hook is a no-op
    try:
        r = subprocess.run(["bash", path], input=claude_json, text=True, capture_output=True, cwd=cwd, env=env, timeout=timeout)
    except Exception:
        return None, None  # mutant-ok delete: timeout or OS error lets tool run

    if r.returncode == 2:
        return f"{name}: {r.stderr.strip() or r.stdout.strip() or f'Blocked by {name}'}", None

    out = r.stdout.strip()
    if out.startswith("{"):
        try:
            resp = json.loads(out)
        except Exception:
            return None, out  # mutant-ok delete: non-JSON stdout starting with { treated as plain text
        hso = resp.get("hookSpecificOutput") or {}
        if hso.get("permissionDecision") == "deny":
            return f"{name}: {hso.get('permissionDecisionReason') or resp.get('reason') or f'Blocked by {name}'}", None
        if resp.get("decision") == "block":
            return f"{name}: {resp.get('reason') or f'Blocked by {name}'}", None
        return None, (hso.get("additionalContext") or resp.get("additionalContext") or None)
    return None, (out or None)


def pre_tool_hooks(tool_name, tool_input):
    if tool_name != "Bash":
        return list(STATIC_PRE_HOOKS.get(tool_name, ()))
    cmd = tool_input.get("command", "")
    return list(dict.fromkeys([h for keys, hs in BASH_PRE_RULES if any(k in cmd for k in keys) for h in hs] + ["approved-test-lock.sh"]))


def post_tool_hooks(tool_name, tool_input):
    if tool_name == "Bash":
        cmd = tool_input.get("command", "")
        hooks = ["pr-guard.sh", "worktree-place.sh", "auto-tidy.sh"] if any(k in cmd for k in ("git", "gh", "tea", "gs")) else []
        return hooks + ["springboard.sh", "approved-test-lock.sh", "repeat-call-hint.sh"]
    return ["springboard.sh", "workflow-lint.sh"] if tool_name in ("Edit", "Write") else []


def collect_injections(scripts_dir, hook_names, claude_json, cwd, env, timeout=15):
    parts = [msg for name in hook_names for msg in (run_script(scripts_dir, name, claude_json, cwd, env, timeout=timeout),) for msg in (msg[0] or msg[1],) if msg]
    return {"injectSteps": [{"systemMessage": {"systemMessage": "\n\n".join(parts)}}]} if parts else {}


def handle_pre_tool(payload, scripts_dir, run_cwd, payload_cwd, env, conv_id, transcript_path):
    tc = payload.get("toolCall") or {}
    ag_tool = tc.get("name") or ""
    if ag_tool not in ARG_MAP:
        return emit({"decision": "allow"})
    tool_name, key_map = ARG_MAP[ag_tool]
    args = tc.get("args") or {}
    tool_input = {dst: args.get(src) or "" for dst, src in key_map.items()}
    claude_json = json.dumps({
        "session_id": conv_id, "transcript_path": transcript_path, "cwd": payload_cwd,
        "hook_event_name": "PreToolUse", "tool_name": tool_name, "tool_input": tool_input,
    })
    for name in pre_tool_hooks(tool_name, tool_input):
        reason, _ = run_script(scripts_dir, name, claude_json, run_cwd, env)
        if reason:
            return emit({"decision": "deny", "reason": reason})
    return emit({"decision": "allow"})


def handle_post_tool(payload, scripts_dir, run_cwd, payload_cwd, env, conv_id, transcript_path):
    tc = payload.get("toolCall") or {}
    ag_tool = tc.get("name") or ""
    if ag_tool not in ARG_MAP:
        return emit({})
    tool_name, key_map = ARG_MAP[ag_tool]
    args = tc.get("args") or {}
    tool_input = {dst: args.get(src) or "" for dst, src in key_map.items()}
    claude_json = json.dumps({
        "session_id": conv_id, "transcript_path": transcript_path, "cwd": payload_cwd,
        "hook_event_name": "PostToolUse", "tool_name": tool_name, "tool_input": tool_input,
        "tool_response": {"error": payload.get("error", "")},
    })
    for name in post_tool_hooks(tool_name, tool_input):
        run_script(scripts_dir, name, claude_json, run_cwd, env)
    return emit({})


def handle_session_start(scripts_dir, run_cwd, payload_cwd, env, conv_id, transcript_path):
    claude_json = json.dumps({
        "session_id": conv_id, "transcript_path": transcript_path, "cwd": payload_cwd,
        "hook_event_name": "SessionStart", "source": "startup",
    })
    hooks = ["auto-tidy.sh", "merged-branch-guard.sh", "todo-reminder.sh", "springboard.sh", "advisory-deadline.sh"]
    return emit(collect_injections(scripts_dir, hooks, claude_json, run_cwd, env, timeout=20))


def handle_pre_invocation(payload, plugin_data, scripts_dir, run_cwd, payload_cwd, env, conv_id, transcript_path):
    prompt = (payload.get("lastUserInput") or "").strip()
    if not prompt:
        return emit({})
    seen_dir = os.path.join(plugin_data, "pre-invocation-seen")
    conv_key = hashlib.sha256((conv_id or "default").encode("utf-8")).hexdigest()[:24]  # mutant-ok: hash key for dedup file
    prompt_hash = hashlib.sha256(prompt.encode("utf-8")).hexdigest()
    seen_file = os.path.join(seen_dir, conv_key)
    try:
        if os.path.isfile(seen_file) and open(seen_file, "r", encoding="utf-8").read().strip() == prompt_hash:
            return emit({})
        os.makedirs(seen_dir, exist_ok=True)
        with open(seen_file, "w", encoding="utf-8") as f:
            f.write(prompt_hash)
    except OSError:
        pass  # mutant-ok delete: unwritable state dir should not block prompt
    claude_json = json.dumps({
        "session_id": conv_id, "transcript_path": transcript_path, "cwd": payload_cwd,
        "hook_event_name": "UserPromptSubmit", "prompt": prompt,
    })
    hooks = ["lesson-hint.sh", "ready-resume-hint.sh", "familiar-voice.sh", "sup-handoff-hint.sh"]
    return emit(collect_injections(scripts_dir, hooks, claude_json, run_cwd, env))


def handle_stop(payload, scripts_dir, run_cwd, payload_cwd, env, conv_id, transcript_path):
    if payload.get("continuationActive") or (payload.get("terminationReason") or "") not in ("", "NO_TOOL_CALL"):
        return emit({"decision": "allow"})
    claude_json = json.dumps({
        "session_id": conv_id, "transcript_path": transcript_path, "cwd": payload_cwd,
        "hook_event_name": "Stop", "stop_hook_active": False,
    })
    for name, t in (("read-before-asking.sh", 10), ("promise-guard.sh", 10), ("cerebro-ask-guard.sh", 10), ("user-test-guard.sh", 10), ("done-check.sh", 300)):
        reason, _ = run_script(scripts_dir, name, claude_json, run_cwd, env, timeout=t)
        if reason:
            return emit({"decision": "continue", "reason": reason})
    return emit({"decision": "allow"})


def main():
    event_arg = sys.argv[1] if len(sys.argv) > 1 else ""
    try:
        payload = json.load(sys.stdin)
    except Exception:
        return emit({"decision": "allow"} if event_arg in ("PreToolUse", "Stop") else {})

    event = event_arg or payload.get("hookEventName") or ""
    plugin_root, plugin_data = resolve_paths()
    scripts_dir = os.path.join(plugin_root, "scripts")
    cwd = payload.get("cwd") or ((payload.get("workspacePaths") or [""])[0])
    project_dir = resolve_project_dir(cwd)
    run_cwd = cwd if (cwd and os.path.isdir(cwd)) else (project_dir if (project_dir and os.path.isdir(project_dir)) else None)  # mutant-ok: subprocess cwd fallback
    payload_cwd = run_cwd or ""
    conv_id = payload.get("conversationId", "")
    transcript_path = payload.get("transcriptPath", "")
    env = build_env(plugin_root, plugin_data, project_dir, conv_id)

    if event == "PreToolUse":
        return handle_pre_tool(payload, scripts_dir, run_cwd, payload_cwd, env, conv_id, transcript_path)
    if event == "PostToolUse":
        return handle_post_tool(payload, scripts_dir, run_cwd, payload_cwd, env, conv_id, transcript_path)
    if event == "SessionStart":
        return handle_session_start(scripts_dir, run_cwd, payload_cwd, env, conv_id, transcript_path)
    if event == "PreInvocation":
        return handle_pre_invocation(payload, plugin_data, scripts_dir, run_cwd, payload_cwd, env, conv_id, transcript_path)
    if event == "Stop":
        return handle_stop(payload, scripts_dir, run_cwd, payload_cwd, env, conv_id, transcript_path)
    return emit({})


if __name__ == "__main__":
    main()
