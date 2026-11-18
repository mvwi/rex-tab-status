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

Each [Rex](https://www.superlogical.com/rex) tab name starts with an emoji for what's happening in it.
I wrote this because I kept clicking through tabs to find the agent that was waiting on me.

![Rex tabs gaining status emoji as agents work, wait and finish](assets/demo.gif)

| Emoji | Means |
|---|---|
| ⏳ | working |
| ✋ | waiting for you to approve something |
| ❓ | waiting for you to answer a question |
| 🔑 | waiting for you to log in |
| ❌ | failed |
| ✅ | finished, and you haven't looked yet |
| (none) | idle, or finished and seen |

Programs report their state to Rex through the
[program status protocol](https://www.superlogical.com/rex/docs/build/program-status) (OSC 7501).
When a tab has several panes, or an agent runs work in the background, the tab shows the
most urgent state.

**Works with:** Claude Code, which reports its state with no setup. Other agents show up once
they support the protocol. I've checked Cursor's CLI (2025.09.18): it doesn't yet. I haven't
tested Codex, Gemini, OpenCode or Amp.

**Runs in:** Rex on macOS. It's built on Rex's own Lua events and tab labels, so it won't
work in iTerm2, Ghostty, Warp or other terminals.

✅ clears when you switch to the tab. Press `cmd+u` to mark a tab seen or unseen by hand,
the way you'd mark mail unread.

## Install

Tell your agent:

> Install github.com/mvwi/rex-tab-status

Or run:

```sh
curl -fsSL https://raw.githubusercontent.com/mvwi/rex-tab-status/v1/install.sh | sh
```

Options go after `sh -s --`:

```sh
curl -fsSL https://raw.githubusercontent.com/mvwi/rex-tab-status/v1/install.sh | sh -s -- --key ctrl+cmd+u
```

| Option | Does |
|---|---|
| `--key COMBO` | bind Toggle Tab Seen to COMBO instead of `cmd+u` |
| `--no-key` | bind no key; the action is still in the command palette |
| `--uninstall` | remove everything, and the emoji from tab names |

The installer refuses a key your `init.lua` already uses. It can't see the Rex app's own
shortcuts, so check the command palette before you pick an unusual one.

macOS only for now.

## What's in the repo

| File | Does |
|---|---|
| `tab-status.lua` | The whole extension. Under `rex do`, it listens for status changes and renames tabs. Loaded from `init.lua`, it adds the Toggle Tab Seen action. |
| `install.sh` | Copies the Lua file, edits `init.lua`, sets up the launchd agent, and checks it started. `--uninstall` reverses each step. |
| `INSTALL.md` | Steps for your agent, if you ask it to install this. It tells the agent to read both files first and ask you before picking a key. |

## What it changes

- Adds `tab-status.lua` beside your `init.lua`.
- Adds a marked block to `init.lua` that loads it and binds the key. Nothing else in the file changes.
- Adds a launchd agent, `io.github.mvwi.rex-tab-status`, that runs
  `rex do tab-status.lua --all` at login and restarts it if it stops. Rex only sends
  events to scripts run this way, not to `init.lua`.
- Keeps seen state in `~/.local/state/rex/tab-status.json` and a log in `tab-status.log` beside it.

`--uninstall` removes all of it.

## Notes

- To change the emoji, edit the tables at the top of `tab-status.lua`, then run
  `rex config reload` and `launchctl kickstart -k gui/$(id -u)/io.github.mvwi.rex-tab-status`.
- "Looking at a tab" means the active tab of its session, even when the app shows a
  different session. Rex doesn't yet tell scripts which session the app shows.
- The default label pattern (`Window 0ab0edc4`) comes from current Rex builds. If a Rex
  update changes it, untitled tabs may keep a stale title.

## FAQ

**Why is something running in the background?**
Rex only sends events to scripts started with `rex do`, not to `init.lua`. Without a
running script, nothing hears that a tab changed state. launchd starts it at login and
restarts it if it dies. It sits idle until Rex sends an event.

**Does it send anything over the network?**
No. The script talks only to the Rex server on your Mac. The installer downloads
`tab-status.lua` from this repo when you pipe it from `curl`, and that's the only download.

**Why not a skill?**
A skill is instructions an agent reads while it works. This has to run when no agent is
running, and it has to react to Rex events, which a skill can't do. You can still have your
agent install it: `INSTALL.md` is written for that.

**Why not `npx`?**
That would make you install Node to copy one Lua file. Rex already runs Lua, and every Mac
has `sh` and `curl`.

**Is `curl | sh` safe?**
As safe as the script you pipe. Read [`install.sh`](install.sh) first; it's about 150 lines
of plain `sh`. Or clone the repo and run `sh install.sh`.

**Will it rename my tabs?**
It only adds an emoji in front. Tabs you named keep your name. Tabs you didn't name show
their terminal title with the emoji in front, then go back to normal when the state clears.

## License

MIT
