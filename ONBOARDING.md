# Onboarding: first run

Sets up a new slack-search agent, **once per agent**. Every step is safe to repeat.

Skip if `~/.slack-search-onboarded` exists. Then only [`AGENTS.md`](AGENTS.md) applies, unless the owner wants to **add a workspace** (below).

Talk to the owner in the language they write in.

**Ask through the harness.** Every question with fixed answers (yes/no, a choice, a pick from a list) goes through the harness's question tool, `AskUserQuestion` on Claude Code: the web chat shows it as clickable options, with "Other" for free text. Put your suggestion first and mark it "(Recommended)". The tool takes up to 4 questions per call and 2–4 options per question; for longer lists, see the paging rule where a step needs it. Ask open questions (names, topics, URLs) as plain text. If the tool is unavailable or fails (e.g. in a Slack thread), ask the same thing as plain text with a numbered list.

**Checklist first:** call `set_onboarding_checklist` with these steps and tick each one with `complete_onboarding_step`:

1. `rule`: The one rule explained
2. `guard`: Write block installed
3. `owner`: Owner confirmed
4. `workspaces`: Slack workspaces recorded
5. `channel`: Private channel checked
6. `exclusions`: Private channels to exclude picked
7. `test`: Test search succeeded

## 1. The one rule (`rule`)

Say this **before any question**, in plain words:

> This agent reads Slack as you. Anyone who can message it can read everything you can read. So never share it, never bind it to a shared channel, and never give anyone else access. Anyone who wants to use it creates their own copy from this kit. The agent only reads. It never writes, reacts or changes anything in Slack.

## 2. Write block (`guard`)

```bash
python3 ~/scripts/install.py
```

The output lists `slack_servers`, the Slack connections of this agent. If the list is empty, no Slack connection is granted. This agent cannot work without one: walk the owner through **Add a workspace** (below) and stop here until it is done.

**Are all workspaces connected?** Each Slack connection covers exactly **one** workspace. A channel in a workspace without its own connection is invisible to this agent, and searching for it ends in "not found". So, when the list is not empty, name the connected servers and ask with `AskUserQuestion`: *"Are all Slack workspaces you want me to cover connected?"*

- **"Yes, that's all" (Recommended):** continue.
- **"I need to add one":** walk through **Add a workspace** (below). A new connection reaches the agent only after a restart, so stop onboarding here and tell the owner: *after the restart, come back to this chat and write "continue".* Then start again at step 2; every step is safe to repeat.
- **"I'm not sure":** explain how to tell: in Slack, the workspace switcher shows every workspace they are in, and a message link of a channel shows its workspace in the domain (`https://<workspace>.slack.com/archives/…`). A channel that later cannot be found is the typical sign of a missing connection.

If the script reports "Not the Claude Code harness", tell the owner clearly that the write tools are **not** blocked, and recommend switching the agent to Claude Code.

The block takes effect from the next session. In this session, call only the read tools this runbook names.

## 3. Owner (`owner`)

Call `slack_read_user_profile` on the first server **without** `user_id`. That profile is the owner. Show the owner the name and ask whether it is them. If it does not match, someone else's Slack account is connected: stop.

Ask for a fallback language. The agent always answers in the language of the question. The fallback applies only when a message has no clear language. Default: `auto`.

## 4. Workspaces (`workspaces`)

For **every** server from step 2:

1. `slack_read_user_profile` without `user_id` on this server: it must show the same person (on Enterprise Grid the user ID can differ per workspace).
2. One search with `slack_search_public_and_private`, e.g. `query: "a"`, `limit: 1`. Take the `permalink_base` from the hit's permalink (e.g. `https://example.enterprise.slack.com`).
3. Suggest a workspace name and have the owner confirm it.

A server with no hits or an error: show it to the owner and ask whether they want to log in again (`dam connection reauth <server>`).

## 5. Private channel (`channel`)

This agent belongs in **one** private channel with only the owner (and the DAM bot). Read the bound channels with `mcp__platform-outbound__describe_channel` (`channel: "slack"`) and check the members with `slack_list_channel_members` (if that fails, `mcp__platform-outbound__describe_channel_users`).

- No channel bound: ask the owner to create a private channel, invite the DAM bot and bind it: `/dam bind` in the channel, or agent → Channels → Add Slack channel in the web app, or `dam channel slack connect <agent> --channel-id <ID> --no-ambient`.
- Members besides the owner and the bot: warn the owner and do not continue until the channel is private.

Keep ambient mode off (`--no-ambient`): then every question starts a fresh session with the current definition.

## 6. Private channels to exclude (`exclusions`)

Say first: *DMs and group DMs are never searched, and neither is this channel.*

Then, for every server in `## workspaces`, list the owner's private channels with `slack_list_user_channels`: restrict it to private channels if the tool offers a type filter, otherwise keep only the private ones from the result, and follow the `cursor` until the list is complete. Leave out the agent's own channel and sort by name.

Ask with `AskUserQuestion`, **multi-select**, one question per workspace: *"Which private channels in <workspace> should I never search?"*, each channel one option (label `#name`). Paging, because a question holds at most 4 options:

- Up to 4 channels: one question with all of them. A question needs at least 2 options, so a single channel gets a second option "None".
- More: split the workspace's list into pages of 4 (`<workspace> 1/3`, `2/3`, …), one question per page, up to 4 pages per call, then the next call. Before the first call, say how many channels and pages there are, and that "Other" accepts channel names typed in directly.
- More than 40 private channels in total: instead of paging through everything, ask first (single choice) whether to page through all, or to type the names to exclude.

Nothing selected on a page means nothing there is excluded. Read the full choice back as names and have it confirmed with one yes/no question. Each chosen channel becomes one row in `## excluded_channels`. Mention that channels can be added or removed later in chat ("never search #x", "search #x again").

Fallback without the tool: a numbered list per workspace, and the owner replies with the numbers, e.g. "1, 2", or "none".

## 7. Write `~/work/CONFIG.md`

Exactly in this shape (values are examples):

```markdown
# Configuration: slack-search

- owner_name: Jane Doe
- owner_slack_user_id: U0123ABCD
- language: auto
- channel_id: C0123ABCD

## workspaces

| server | workspace | permalink_base |
| --- | --- | --- |
| slack-account | Example Corp | https://example.enterprise.slack.com |
| slack-partner | Partner Inc | https://example.enterprise.slack.com |

## excluded_channels

| server | channel_id | name |
| --- | --- | --- |
| slack-account | C0456EFGH | #proj-acme |
| slack-account | C0789IJKL | #proj-zeta |
```

If the owner picked none, keep the heading and the table header with no rows.

Show the file to the owner.

## 8. Test search (`test`)

Ask the owner for a term they are sure to find in Slack, and answer the question once in full per [`AGENTS.md`](AGENTS.md), with sources from all workspaces.

## 9. Finish

```bash
mkdir -p ~/work/state && date -u +%Y-%m-%dT%H:%M:%SZ > ~/.slack-search-onboarded
```

Then call `mark_onboarding_complete` and summarize briefly:

1. the `CONFIG.md`
2. how to ask: post a question in the private channel and @-mention the bot
3. how to add a workspace (below)
4. once more: **never share this agent**

## Add a workspace (any time)

Guide the owner through these steps, with this agent's name filled in for `<agent>`:

1. **Find the workspace:** in Slack, open a channel of that workspace and copy a message link; the domain is the workspace (`https://<workspace>.slack.com/…`).
2. **Create the connection:**
   - Web app: Settings → Connections → **Add connection** → Apps → **Slack Account** → **New**. In Slack's login dialog, pick that workspace in the top-right corner.
   - CLI: `dam connection connect slack --name slack-<workspace>`, and pick the workspace in the login dialog.
3. **Grant it to this agent:** in the web app under the agent's connections, or `dam connection grant <agent> --connection slack-<workspace>`.
4. **Restart the agent:** in the web app, or `dam agent restart <agent>`.

If Slack's login dialog does not offer the workspace, the DAM Slack app is not installed there; only that workspace's admins can add it.

After the restart, the SessionStart hook reports the new server. Run step 4 for it, run step 6 for its private channels, add the row to `## workspaces` and confirm it in one sentence. Ask whether to look up any channels there again that were not found before. The hook installs the write block for the new server itself.
