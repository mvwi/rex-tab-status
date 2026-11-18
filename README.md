```
  █████              █████                 █████               █████
 ▒▒███              ▒▒███                 ▒▒███               ▒▒███
 ███████    ██████   ▒███████      █████  ███████    ██████   ███████   █████ ████  █████
▒▒▒███▒    ▒▒▒▒▒███  ▒███▒▒███    ███▒▒  ▒▒▒███▒    ▒▒▒▒▒███ ▒▒▒███▒   ▒▒███ ▒███  ███▒▒
  ▒███      ███████  ▒███ ▒███   ▒▒█████   ▒███      ███████   ▒███     ▒███ ▒███ ▒▒█████
  ▒███ ███ ███▒▒███  ▒███ ▒███    ▒▒▒▒███  ▒███ ███ ███▒▒███   ▒███ ███ ▒███ ▒███  ▒▒▒▒███
  ▒▒█████ ▒▒████████ ████████     ██████   ▒▒█████ ▒▒████████  ▒▒█████  ▒▒████████ ██████
   ▒▒▒▒▒   ▒▒▒▒▒▒▒▒ ▒▒▒▒▒▒▒▒     ▒▒▒▒▒▒     ▒▒▒▒▒   ▒▒▒▒▒▒▒▒    ▒▒▒▒▒    ▒▒▒▒▒▒▒▒ ▒▒▒▒▒▒
                                                      _                , __
                                                     | |              /|/  \          |
                                                     | |  __   ,_      |___/  _       |
                                                     |/  /  \_/  |     | \   |/  /\/  |
                                                     |__/\__/    |_/   |  \_/|__/ /\_/o
                                                     |\
                                                     |/
```

**Know which agent needs you. Without opening every tab!\***

<sub>\* Agents left waiting are not the responsibility of Tab Status.</sub>

rex-tab-status adds an emoji to each [Rex](https://www.superlogical.com/rex) tab name that
shows what the agent in that tab is doing.

![Rex tabs gaining status emoji as agents work, wait and finish](assets/demo.gif)

| Emoji | Meaning |
|---|---|
| ⏳ | Working |
| ✋ | Waiting for you to approve an action |
| ❓ | Waiting for you to answer a question |
| 🔑 | Waiting for you to log in |
| ❌ | Failed |
| ✅ | Finished, and you haven't looked yet |
| (none) | Idle, or finished and seen |

When a tab has several panes, or an agent runs work in the background, the tab shows the most
urgent state. ✅ clears when you switch to the tab. Press `cmd+u` to mark the current tab seen
or unseen.

## Supported agents

| Agent | Supported | How |
|---|---|---|
| Claude Code | Yes | Reports its state to Rex natively |
| Codex | Yes | Reports its state to Rex natively |
| OpenCode | Yes | Reports its state to Rex natively |
| Gemini CLI | Yes | Hooks, which the installer adds as a Gemini extension |
| Cursor CLI | Not yet | Cursor has no hook that fires while the agent waits for approval |
| Amp | Not yet | Amp has no command hooks |

Any program that reports its state with the
[program status protocol](https://www.superlogical.com/rex/docs/build/program-status)
(OSC 7501) works without changes.

rex-tab-status runs in Rex on macOS. It uses Rex's Lua events and tab labels, which other
terminals don't have.

## Install

Ask your agent:

> Install github.com/mvwi/rex-tab-status

Or run:

```sh
curl -fsSL https://raw.githubusercontent.com/mvwi/rex-tab-status/v2/install.sh | sh
```

Pass options after `sh -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/mvwi/rex-tab-status/v2/install.sh | sh -s -- --key ctrl+cmd+u
```

| Option | Effect |
|---|---|
| `--key COMBO` | Binds Toggle Tab Seen to `COMBO` instead of `cmd+u` |
| `--no-key` | Binds no key. The action stays in the command palette. |
| `--uninstall` | Removes everything the installer added, and the emoji from tab names |

The installer refuses a key that your `init.lua` already uses. It can't see the Rex app's
built-in shortcuts, so check the command palette before you choose an unusual key.

## What's in the repo

| File | Purpose |
|---|---|
| `tab-status.lua` | The extension. Under `rex do`, it listens for status changes and renames tabs. Loaded from `init.lua`, it adds the Toggle Tab Seen action. |
| `install.sh` | Copies the Lua file, edits `init.lua`, starts the background listener, and installs the Gemini CLI extension if Gemini CLI is present. `--uninstall` reverses each step. |
| `hooks/report.sh` | Reports an agent's state to Rex for agents that don't report it themselves. Gemini CLI runs it. |
| `hooks/hooks.json`, `gemini-extension.json` | The Gemini CLI extension that calls `report.sh` |
| `INSTALL.md` | Instructions for an agent that installs this for you. The agent reads both scripts first and asks before it picks a key. |

## What the installer changes

- Adds `tab-status.lua` next to your `init.lua`.
- Adds a marked block to `init.lua` that loads the extension and binds the key. The rest of the
  file stays the same.
- Adds a launchd agent, `io.github.mvwi.rex-tab-status`, that runs `rex do tab-status.lua --all`
  at login and restarts it if it stops.
- Stores seen state in `~/.local/state/rex/tab-status.json` and a log in `tab-status.log` in
  the same folder.
- If Gemini CLI is installed, adds the `rex-tab-status` Gemini extension.

`--uninstall` removes all of it.

## Customize the emoji

Edit the tables at the top of `tab-status.lua`, then run:

```sh
rex config reload
launchctl kickstart -k gui/$(id -u)/io.github.mvwi.rex-tab-status
```

## FAQ

**Why does it run in the background?**
Rex sends events only to scripts started with `rex do`, not to `init.lua`. Without a running
script, nothing notices when a tab changes state. launchd starts the script at login and
restarts it if it stops. The script stays idle until Rex sends an event.

**Does it send data over the network?**
No. The script talks only to the Rex server on your Mac. When you pipe the installer from
`curl`, it downloads `tab-status.lua` from this repo. That is the only download.

**Why isn't this a skill?**
A skill is instructions that an agent reads while it works. This extension has to run when no
agent is running and react to Rex events, which a skill can't do. Your agent can still install
it for you: `INSTALL.md` is written for that.

**Why isn't this an `npx` package?**
An `npx` package would require Node to copy one Lua file. Rex already runs Lua, and every Mac
has `sh` and `curl`.

**Is `curl | sh` safe?**
Read [`install.sh`](install.sh) before you run it. It's about 170 lines of plain `sh`. You can
also clone the repo and run `sh install.sh`.

**Will it rename my tabs?**
It adds an emoji in front of the name. Tabs you named keep their names. Tabs you didn't name
show the terminal title with the emoji in front, and return to normal when the state clears.

## Known limitations

- "Looking at a tab" means the active tab of its session, even when the app shows a different
  session. Rex doesn't yet tell scripts which session the app shows.
- The extension recognizes untitled tabs by Rex's current default label (`Window 0ab0edc4`). If
  a Rex update changes that pattern, untitled tabs may keep a stale title.

## License

MIT
