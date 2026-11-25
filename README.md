# Slack Search: DAM starter kit

Ask your Slack in natural language. The agent searches every Slack workspace you connect, reads the matching threads, and answers with a short summary and permalinks, in the language you asked in. **It only reads**: writing to Slack is technically blocked.

> ⚠️ **The agent acts as you in Slack.** Anyone who can message it can read everything you can read, including your private channels and DMs. Never share it, and bind it only to a private channel with nobody but you in it. Anyone who wants to use it creates their own copy from this kit.

## What you need

- Access to a DAM host and an account on it.
- The **DAM Slack app** installed in each Slack workspace you want to search. If it is missing, the Slack login fails. Ask your DAM administrator or the workspace admins to install it.
- About 10 minutes. You do **not** need the `dam` CLI; everything works in the web app. CLI commands are listed as an alternative.

## Setup

### 1. Connect your Slack account

The agent reads Slack through a **Slack Account** connection. It acts with your permissions.

- **Web app:** Settings → Connections → **Add connection** → Connection catalog → **Apps** tab → **New** on the **Slack Account** card. Sign in to Slack. In the top-right corner of Slack's login dialog, pick the workspace you want.
- **CLI:**
  ```bash
  dam connection connect slack --name slack-account
  ```

**More workspaces** (e.g. a partner or second company workspace): add another Slack Account connection and pick the other workspace in the login dialog. With the CLI, give each a clear name, e.g. `--name slack-partner`. The agent detects every Slack connection on its own, whatever its name.

### 2. Create a private channel for the agent

1. In Slack, create a **private** channel, e.g. `#my-slack-search`. Don't add anyone else.
2. Invite the **DAM** app to the channel (channel details → Integrations → Add apps, or mention `@DAM` and accept the invite prompt).
3. Run `/dam login` once in the channel so DAM knows your Slack account.

### 3. Create the agent from the kit

- **Web app:**
  1. Home → **Browse starter kits** → **Import from link**.
  2. Paste the link of this repository (the repo itself, not a branch or folder) and click **Open kit**.
  3. The dialog shows what the kit sets up. Give the agent a name (e.g. `slack-search`), grant your Slack Account connection(s), and create it.
- **CLI:**
  ```bash
  dam kit show <repo-url>          # what the kit sets up and needs
  dam agent create slack-search --kit <repo-url> \
    --connection slack-account --connection slack-partner
  ```

The harness must be **Claude Code** (the kit allows nothing else). The write block does not work on other harnesses.

### 4. Bind the channel

- **Web app:** open the agent → **Channels** → Slack card → **Add Slack channel** → pick your private channel. Leave **ambient mode off**.
- **In Slack:** in the channel, run `/dam bind` and pick the agent.
- **CLI:**
  ```bash
  dam channel slack connect slack-search --channel-id <channel-id> --no-ambient
  ```

With ambient mode off, every question starts a fresh session, so the agent always works with its current setup.

### 5. Onboarding (first session)

Open the agent's chat in the web app. The first session walks you through setup with a checklist:

1. explains the one rule (never share this agent)
2. installs the write block for every Slack connection
3. reads your Slack profile and asks you to confirm it is you
4. detects your workspaces and their permalink domains
5. checks that the bound channel is private
6. lists your private channels and lets you pick the ones it should never search
7. runs a test search with a term you choose

Your settings land in `~/work/CONFIG.md` on the agent. Nothing personal goes into this repository.

## Usage

In your private channel, mention the bot and ask, e.g.:

> @DAM What did we decide about the Q3 launch date?
> @DAM Wer hat zuletzt über das Release-Datum gesprochen?

The agent answers in the language of your question. It searches in that language and in English, reads up to about 10 threads, and lists its sources with permalinks. If it finds nothing, it says which searches it ran and suggests a better phrasing.

## What is never searched

- **DMs and group DMs:** always excluded.
- **The agent's own channel:** always excluded, so it never finds its own earlier answers.
- **Private channels you pick:** during onboarding the agent lists your private channels and you pick the ones to exclude, e.g. project channels. Change the list any time in chat: "never search #proj-acme", "search #proj-acme again", "which channels are excluded?".

## Adding a workspace later

1. Add another Slack Account connection (step 1) and grant it to the agent (agent → Connections, or `dam connection grant slack-search --connection <name>`).
2. Restart the agent (`dam agent restart slack-search`, or restart it in the web app).
3. On its next session, the agent reports the new workspace and asks whether to add it. It installs the write block for it itself.

## Updates

Agents don't update on their own. When this repository has a newer version, the owner decides:

```bash
dam kit changes <agent>   # what the new version brings (commits and CHANGELOG.md)
dam kit update <agent>    # take it: the agent applies it in a session of its own
dam kit skip <agent>      # skip this version; the next one is offered again
```

During the update the agent replaces only the definition files. Everything under `~/work/` (your settings and history) stays as it is. If a version needs a new setting, the agent asks you for it. See [`CHANGELOG.md`](CHANGELOG.md) for what changed in each version.

## Troubleshooting

| Symptom | Fix |
|---|---|
| "Slack servers: none" during onboarding | No Slack connection is granted to the agent. Grant it, then restart. |
| A workspace is missing from answers | Its login expired. Run `dam connection reauth <name>` or reconnect it in Settings → Connections. |
| The Slack login doesn't offer the workspace | The DAM Slack app is not installed there. Ask the workspace admins. |
| A channel can't be found | You must be a member of the channel, and it must be in a connected workspace. |
| The agent refuses to search and warns you | Someone else is a member of the bound channel. Remove them, or use a new private channel. |

## Layout

| File | Purpose |
|---|---|
| `kit.yaml` | Kit manifest for DAM |
| `VERSION`, `CHANGELOG.md` | Installed version and what changed in each version |
| `AGENTS.md` | The agent's operating manual |
| `ONBOARDING.md` | Setup on first run |
| `scripts/install.py` | Detects the Slack servers in `~/.mcp.json` and writes the deny list and hooks into `~/.claude/settings.json`. Runs at every session start. |
| `scripts/slack-guard.sh` | PreToolUse hook: lets only Slack read tools through, blocks unknown tools and direct Slack calls from the shell |
| `scripts/slack-tools.txt` | Classifies every Slack tool as `read` or `write` |
| `scripts/deny-extra.txt` | Further blocked tools (WebFetch, WebSearch) |

Everything you configure lives on the agent under `~/work/` and is never versioned.
