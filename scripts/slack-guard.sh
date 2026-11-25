#!/usr/bin/env bash
# PreToolUse hook (Claude Code). Slack is READ-ONLY for this agent: every Slack
# connection acts as its owner, so a write tool would be the owner speaking.
# Registered by scripts/install.py.
#
#   Slack tool (server with "slack" in its name, or tool name slack_*)
#       -> allowed only when slack-tools.txt classifies it as `read`.
#          Unknown tools are blocked (fail closed).
#   Bash
#       -> blocked when the command reaches Slack directly
#          (the gateway would inject the owner's token).
#
# Blocked = exit 2, the reason goes to stderr.
set -u
INPUT="$(cat 2>/dev/null || true)"
[ -z "$INPUT" ] && exit 0
case "$INPUT" in (*[sS][lL][aA][cC][kK]*) ;; (*) exit 0;; esac

DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_FILE="$DIR/slack-tools.txt"
KIT="$(sed -n 's/^id:[[:space:]]*//p' "$DIR/../kit.yaml" 2>/dev/null | head -1)"
KIT="${KIT:-agent}"
LOG="${HOME:-/home/agent}/work/state/slack-guard.log"

field() { # <jq path> <sed key>
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r "$1 // empty" 2>/dev/null
  else
    printf '%s' "$INPUT" | sed -n "s/.*\"$2\"[[:space:]]*:[[:space:]]*\"\([^\"]*\)\".*/\1/p" | head -1
  fi
}
TOOL="$(field .tool_name tool_name)"

block() {
  mkdir -p "$(dirname "$LOG")" 2>/dev/null
  printf '%s BLOCKED %s: %s\n' "$(date -u +%FT%TZ)" "$TOOL" "$1" >> "$LOG" 2>/dev/null
  printf '%s: blocked — %s. Slack is read-only for this agent: the Slack connection acts as its owner, so this agent never posts, reacts, drafts, schedules, creates or uploads anything in Slack. Answers go only through the platform tools (mcp__platform-outbound__reply / start_thread / post) into the bound channel.\n' "$KIT" "$1" >&2
  exit 2
}

case "$TOOL" in
  (mcp__*__*)
    rest="${TOOL#mcp__}"; server="${rest%%__*}"; name="${rest#*__}"
    case "$server" in (platform-outbound) exit 0;; esac
    is_slack=0
    case "$server" in (*[sS][lL][aA][cC][kK]*) is_slack=1;; esac
    case "$name" in (slack_*) is_slack=1;; esac
    [ "$is_slack" = 1 ] || exit 0
    [ -r "$TOOLS_FILE" ] || block "slack-tools.txt is unreadable, so no Slack tool can be judged safe"
    class="$(sed -e 's/#.*//' "$TOOLS_FILE" | awk -v t="$name" '$2 == t {print $1; exit}')"
    case "$class" in
      (read) exit 0;;
      (write) block "$name writes to Slack";;
      (*) block "$name is not classified as read in slack-tools.txt"
    esac
    ;;
  (Bash)
    CMD="$(field .tool_input.command command)"
    [ -n "$CMD" ] || CMD="$INPUT"
    if printf '%s' "$CMD" | grep -qiE '(mcp|api|hooks|files|wss-[a-z0-9-]*)\.slack\.com|slack\.com/api'; then
      block "a shell command that reaches Slack directly"
    fi
    ;;
esac
exit 0
