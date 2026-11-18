# Installing rex-tab-status (for agents)

You're installing a Rex extension for your user. Follow these steps in order.

1. **Read before running.** Read `tab-status.lua` and `install.sh` in this repo. Tell the
   user, in a sentence, that the install adds a block to their Rex `init.lua` and a launchd
   agent that keeps a `rex do` script running in the background.
2. **Check that it applies.** Run `uname` (must be `Darwin`) and `rex whoami` (must succeed).
   If either fails, stop and tell the user why.
3. **Pick a key.** Run `rex keymap`. The default is `cmd+u`. If it's taken, or the user
   wants another, ask them, and pass `--key COMBO`, or `--no-key` if they want none.
   Don't pick a key on their behalf without asking.
4. **Run it:** `sh install.sh [--key COMBO | --no-key]` from a clone, or the `curl` line in
   the README. Don't edit `init.lua` by hand; the script manages a marked block in it.
5. **Check the result:**
   - `rex keymap` lists `tab_seen_toggle` on the chosen key.
   - `launchctl print gui/$(id -u)/io.github.mvwi.rex-tab-status` shows `state = running`.
   - `~/.local/state/rex/tab-status.log` contains a line starting with `listening`.
   - Any tab where Claude Code is working shows ⏳ at the start of its name.
6. **Report** the key, and that `install.sh --uninstall` removes everything.

If a step fails, show the user the error rather than working around it.
