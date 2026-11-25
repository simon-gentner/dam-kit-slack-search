# Changelog

All notable changes to this kit. The version in `VERSION` is the one installed on an agent.
`dam kit changes <agent>` shows what an update brings; `dam kit update <agent>` takes it.

## 0.3.2 (2026-11-25)

- Onboarding now checks that every Slack workspace the owner wants covered has its own connection, and guides through adding one (web app or CLI, grant, restart, then continue onboarding). A channel in an unconnected workspace was reported as not found before.
- "Add a workspace" is a step-by-step guide, including how to find a channel's workspace and what to do when Slack's login does not offer it.

## 0.3.1 (2026-11-25)

- Fix: a channel named in chat ("never search #x") is now looked up on every connected workspace, and in the owner's own channel list with all pages when the name search finds nothing. Private channels and channels in a second workspace were reported as not found before.

## 0.3.0 (2026-11-25)

- Kit updates: the agent now applies a `dam kit update` itself. It takes the new definition files as they are, leaves `~/work/` untouched, re-runs `install.py` and reports what changed.
- Added `VERSION` and this changelog.

## 0.2.0 (2026-11-25)

- DMs, group DMs and the agent's own channel are never searched.
- New setting `## excluded_channels` in `~/work/CONFIG.md`: private channels the owner never wants searched. **On update:** if the table is missing, run ONBOARDING.md step 6 to let the owner pick channels, then add the table (it may stay empty).
- Onboarding asks fixed-answer questions through the harness (`AskUserQuestion`), with a numbered-list fallback.

## 0.1.0 (2026-11-25)

- First version: read-only Slack search across every connected workspace, answers in the language of the question with permalinks.
- Write block for all Slack connections, detected at runtime from `~/.mcp.json`.
