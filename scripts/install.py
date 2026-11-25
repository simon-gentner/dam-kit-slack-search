#!/usr/bin/env python3
"""Installs the Slack write block into ~/.claude/settings.json (Claude Code).

  install.py                 install or refresh, print the result
  install.py --check         check only; exit 1 when something is missing
  install.py --session-start same as without option, but print one short line for
                             the context (runs as a SessionStart hook on every start)

The Slack servers are read from ~/.mcp.json: every connection to mcp.slack.com counts,
whatever its name. For each server, every `write` tool from slack-tools.txt goes into
permissions.deny, plus the entries of deny-extra.txt (if present), and every `read` tool
goes into permissions.allow. The allow entries keep Claude Code's auto-mode classifier
from refusing harmless reads (e.g. slack_list_channel_members) at random. This script's own
entries from an earlier run are replaced; everyone else's stay. The hooks
(PreToolUse -> slack-guard.sh, SessionStart -> this script) are added idempotently.
Changes take effect from the next session; slack-guard.sh blocks every unclassified
Slack tool regardless.
"""
import json
import os
import re
import sys
from pathlib import Path

HOME = Path(os.environ.get("HOME", "/home/agent"))
SCRIPTS = Path(__file__).resolve().parent
SETTINGS = Path(os.environ.get("CLAUDE_SETTINGS", HOME / ".claude" / "settings.json"))
MCP_JSON = HOME / ".mcp.json"
CONFIG = HOME / "work" / "CONFIG.md"


def kit_id():
    m = re.search(r"^id:\s*(\S+)", (SCRIPTS.parent / "kit.yaml").read_text(), re.M)
    return m.group(1) if m else "agent"


def slack_servers():
    try:
        servers = json.loads(MCP_JSON.read_text()).get("mcpServers", {})
    except (OSError, ValueError):
        return []
    return sorted(name for name, cfg in servers.items()
                  if "slack.com" in str(cfg.get("url", "")) or "slack" in name.lower())


def tool_lines(kind):
    out = []
    for line in (SCRIPTS / "slack-tools.txt").read_text().splitlines():
        parts = line.split("#", 1)[0].split()
        if len(parts) == 2 and parts[0] == kind:
            out.append(parts[1])
    return out


def extra_deny():
    f = SCRIPTS / "deny-extra.txt"
    if not f.exists():
        return []
    return [l.split("#", 1)[0].strip() for l in f.read_text().splitlines() if l.split("#", 1)[0].strip()]


def desired_deny(servers):
    writes = tool_lines("write")
    return [f"mcp__{s}__{t}" for s in servers for t in writes] + extra_deny()


def desired_allow(servers):
    reads = tool_lines("read")
    return [f"mcp__{s}__{t}" for s in servers for t in reads]


def guard_cmd():
    return f"bash {SCRIPTS / 'slack-guard.sh'}"


def start_cmd():
    return f"python3 {SCRIPTS / 'install.py'} --session-start"


def merge(current, owned_prev, new):
    """Replace this script's own entries from an earlier run; keep everyone else's."""
    return [x for x in current if x not in owned_prev and x not in new] + new


def apply(settings, servers, owned_prev):
    deny_new, allow_new = desired_deny(servers), desired_allow(servers)
    perms = settings.setdefault("permissions", {})
    perms["deny"] = merge(perms.get("deny", []), owned_prev["deny"], deny_new)
    perms["allow"] = merge(perms.get("allow", []), owned_prev["allow"], allow_new)

    hooks = settings.setdefault("hooks", {})
    pre = [h for h in hooks.get("PreToolUse", [])
           if not any("slack-guard.sh" in x.get("command", "") for x in h.get("hooks", []))]
    pre.append({"matcher": "mcp__.*|Bash",
                "hooks": [{"type": "command", "command": guard_cmd(), "timeout": 10}]})
    hooks["PreToolUse"] = pre

    start = [h for h in hooks.get("SessionStart", [])
             if not any("install.py" in x.get("command", "") for x in h.get("hooks", []))]
    start.append({"hooks": [{"type": "command", "command": start_cmd(), "timeout": 20}]})
    hooks["SessionStart"] = start
    return settings, {"deny": deny_new, "allow": allow_new}


def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else ""
    kit = kit_id()
    harness_ok = os.environ.get("CLAUDECODE") == "1" or os.environ.get("PLATFORM_HARNESS") == "claude-code"
    if not harness_ok and os.environ.get("KIT_FORCE_CLAUDE") != "1":
        print(f"{kit}: Not the Claude Code harness, nothing installed. Without this block the "
              "Slack write tools are NOT blocked. Tell the owner and recommend Claude Code.")
        return 0

    servers = slack_servers()
    owned_file = SETTINGS.parent / f".{kit}-owned-deny.json"
    try:
        owned_prev = json.loads(owned_file.read_text())
    except (OSError, ValueError):
        owned_prev = {}
    if isinstance(owned_prev, list):  # format before 0.3.3: deny entries only
        owned_prev = {"deny": owned_prev}
    owned_prev = {"deny": owned_prev.get("deny", []), "allow": owned_prev.get("allow", [])}
    try:
        settings = json.loads(SETTINGS.read_text()) if SETTINGS.exists() and SETTINGS.stat().st_size else {}
    except ValueError:
        print(f"{kit}: {SETTINGS} is not valid JSON, nothing changed.")
        return 1

    before = json.dumps(settings, sort_keys=True)
    new, owned_new = apply(json.loads(before), servers, owned_prev)
    changed = json.dumps(new, sort_keys=True) != before

    if mode == "--check":
        print("current" if not changed else "not current: run install.py")
        return 1 if changed else 0

    if changed:
        SETTINGS.parent.mkdir(parents=True, exist_ok=True)
        tmp = SETTINGS.with_suffix(".tmp")
        tmp.write_text(json.dumps(new, indent=2, ensure_ascii=False) + "\n")
        tmp.replace(SETTINGS)
    owned_file.write_text(json.dumps(owned_new))

    config = CONFIG.read_text() if CONFIG.exists() else ""
    unknown = [s for s in servers if f"| {s} |" not in config and f"|{s}|" not in config]

    if mode == "--session-start":
        line = f"[{kit}] Slack servers: {', '.join(servers) or 'none'}."
        if changed:
            line += " Write block updated (takes effect next session; slack-guard.sh already blocks now)."
        if config and unknown:
            line += (f" Not in work/CONFIG.md: {', '.join(unknown)}. Ask the owner whether to add the "
                     "workspace (ONBOARDING.md → Add a workspace).")
        if not config:
            line += " Not set up yet: follow ONBOARDING.md."
        print(line)
        return 0

    print(json.dumps({"kit": kit, "slack_servers": servers, "deny_entries": len(owned_new["deny"]), "allow_entries": len(owned_new["allow"]),
                      "changed": changed, "settings": str(SETTINGS),
                      "not_in_config": unknown}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
