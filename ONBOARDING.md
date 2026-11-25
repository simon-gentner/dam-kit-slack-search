# Onboarding: first run

Sets up a new slack-search agent, **once per agent**. Every step is safe to repeat.

Skip if `~/.slack-search-onboarded` exists. Then only [`AGENTS.md`](AGENTS.md) applies, unless the owner wants to **add a workspace** (below).

Talk to the owner in the language they write in, a few questions per message, each with a suggestion they can accept.

**Checklist first:** call `set_onboarding_checklist` with these steps and tick each one with `complete_onboarding_step`:

1. `rule`: The one rule explained
2. `guard`: Write block installed
3. `owner`: Owner confirmed
4. `workspaces`: Slack workspaces recorded
5. `channel`: Private channel checked
6. `test`: Test search succeeded

## 1. The one rule (`rule`)

Say this **before any question**, in plain words:

> This agent reads Slack as you. Anyone who can message it can read everything you can read. So never share it, never bind it to a shared channel, and never give anyone else access. Anyone who wants to use it creates their own copy from this kit. The agent only reads. It never writes, reacts or changes anything in Slack.

## 2. Write block (`guard`)

```bash
python3 ~/scripts/install.py
```

The output lists `slack_servers`, the Slack connections of this agent. If the list is empty, the Slack connection is missing: ask the owner to create and grant one, and stop here.

```bash
dam connection connect slack --name slack-<workspace>
dam connection grant <agent> --connection slack-<workspace>
```

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

This agent belongs in **one** private channel with only the owner (and the DAM bot). Read the bound channels with `mcp__platform-outbound__describe_channel` (`channel: "slack"`) and check the members with `slack_list_channel_members`.

- No channel bound: ask the owner to create a private channel, invite the DAM bot and bind it: `/dam bind` in the channel, or agent → Channels → Add Slack channel in the web app, or `dam channel slack connect <agent> --channel-id <ID> --no-ambient`.
- Members besides the owner and the bot: warn the owner and do not continue until the channel is private.

Keep ambient mode off (`--no-ambient`): then every question starts a fresh session with the current definition.

## 6. Write `~/work/CONFIG.md`

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
```

Show the file to the owner.

## 7. Test search (`test`)

Ask the owner for a term they are sure to find in Slack, and answer the question once in full per [`AGENTS.md`](AGENTS.md), with sources from all workspaces.

## 8. Finish

```bash
mkdir -p ~/work/state && date -u +%Y-%m-%dT%H:%M:%SZ > ~/.slack-search-onboarded
```

Then call `mark_onboarding_complete` and summarize briefly:

1. the `CONFIG.md`
2. how to ask: post a question in the private channel and @-mention the bot
3. how to add a workspace (below)
4. once more: **never share this agent**

## Add a workspace (any time)

The owner creates and grants the connection:

```bash
dam connection connect slack --name slack-<workspace>
dam connection grant <agent> --connection slack-<workspace>
dam agent restart <agent>
```

In Slack's login dialog, they pick the right workspace in the top right. After that, the SessionStart hook reports the new server. Run step 4 for it, add the row to `## workspaces` and confirm it in one sentence. The hook adds the write block for the new server itself. It takes effect from the next session, and `slack-guard.sh` blocks writes even before that.
