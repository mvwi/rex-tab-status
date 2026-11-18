#!/bin/sh
# rex-tab-status installer. Run from a clone, or:
#   curl -fsSL https://raw.githubusercontent.com/mvwi/rex-tab-status/v2/install.sh | sh
# Options:
#   --key COMBO   bind Toggle Tab Seen to COMBO (default cmd+u)
#   --no-key      don't bind a key; the action is still in the command palette
#   --uninstall   remove everything this script added, and the emoji from tab names
set -eu

REF=v2
REPO=mvwi/rex-tab-status
KEY=cmd+u
MODE=install

while [ $# -gt 0 ]; do
  case $1 in
  --key) KEY=${2:?--key needs a key combination, such as cmd+u}; shift ;;
  --key=*) KEY=${1#--key=} ;;
  --no-key) KEY= ;;
  --uninstall) MODE=uninstall ;;
  -h | --help) echo "usage: install.sh [--key COMBO | --no-key] [--uninstall]"; exit 0 ;;
  *) echo "unknown option: $1" >&2; exit 2 ;;
  esac
  shift
done

warn() { printf '  ! %s\n' "$*"; }
ok() { printf '  \342\234\223 %s\n' "$*"; }
die() { printf '  \342\234\227 %s\n' "$*" >&2; exit 1; }

[ "$(uname)" = Darwin ] || die "macOS only for now (it uses launchd to keep the listener running)"
REX=$(command -v rex) || die "rex not found on PATH. Install Rex first: https://www.superlogical.com/rex"
"$REX" whoami >/dev/null 2>&1 || die "rex can't reach its server. Open Rex and try again."

CONFIG=${REX_CONFIG:-${XDG_CONFIG_HOME:-$HOME/.config}/rex/init.lua}
CONFIG_DIR=$(dirname "$CONFIG")
LUA=$CONFIG_DIR/tab-status.lua
STATE=${XDG_STATE_HOME:-$HOME/.local/state}/rex
LOG=$STATE/tab-status.log
LABEL=io.github.mvwi.rex-tab-status
PLIST=$HOME/Library/LaunchAgents/$LABEL.plist
DOMAIN=gui/$(id -u)
BEGIN='-- rex-tab-status: begin (managed by install.sh)'
END='-- rex-tab-status: end'

# Remove our block from init.lua, leaving the rest untouched.
strip_config() {
  [ -f "$CONFIG" ] || return 0
  awk -v b="$BEGIN" -v e="$END" '$0 == b { skip = 1; next } $0 == e { skip = 0; next } !skip' "$CONFIG" >"$CONFIG.tmp"
  mv "$CONFIG.tmp" "$CONFIG"
}

# bootout returns before launchd lets go of the label, so wait, or bootstrap fails with error 5.
stop_agent() {
  launchctl bootout "$DOMAIN/$LABEL" 2>/dev/null || true
  i=0
  while launchctl print "$DOMAIN/$LABEL" >/dev/null 2>&1 && [ $i -lt 20 ]; do i=$((i + 1)); sleep 0.25; done
}

echo "rex-tab-status $REF"

if [ "$MODE" = uninstall ]; then
  stop_agent
  rm -f "$PLIST"
  ok "stopped and removed the launchd agent"
  if [ -f "$LUA" ]; then
    TAB_STATUS_CLEAN=1 "$REX" do "$LUA" >/dev/null 2>&1 || true
    ok "removed the emoji from tab names"
  fi
  strip_config
  "$REX" config reload >/dev/null 2>&1 || true
  ok "removed the init.lua block and reloaded the config"
  rm -f "$LUA" "$STATE/tab-status.json" "$LOG"
  ok "deleted tab-status.lua and its state"
  if command -v gemini >/dev/null 2>&1 && gemini extensions uninstall rex-tab-status >/dev/null 2>&1; then
    ok "removed the Gemini CLI extension"
  fi
  exit 0
fi

# Key check: refuse a key the config file already uses for something else.
if [ -n "$KEY" ]; then
  KEY=$(printf '%s' "$KEY" | tr 'A-Z' 'a-z')
  # Compare with modifiers sorted, so shift+cmd+u matches cmd+shift+u.
  taken=$("$REX" keymap 2>/dev/null | awk -v want="$KEY" '
    function norm(k,   p, n, i, j, t, out) {
      n = split(tolower(k), p, "+")
      for (i = 1; i < n - 1; i++) for (j = i + 1; j < n; j++) if (p[j] < p[i]) { t = p[i]; p[i] = p[j]; p[j] = t }
      out = p[n]; for (i = n - 1; i >= 1; i--) out = p[i] "+" out
      return out
    }
    NR > 1 && NF >= 2 && norm($1) == norm(want) && $2 != "tab_seen_toggle" { print $2 " (" $NF ")"; exit }')
  [ -z "$taken" ] || die "$KEY is already bound to $taken. Rerun with --key COMBO or --no-key."
fi

mkdir -p "$CONFIG_DIR" "$STATE" "$(dirname "$PLIST")"

# The Lua file: from this clone if we're in one, else from the same tag as this script.
# Piped from curl, $0 is the shell, not this file.
here=
case $0 in */install.sh | install.sh) here=$(cd "$(dirname "$0")" && pwd) ;; esac
if [ -n "$here" ] && [ -f "$here/tab-status.lua" ]; then
  cp "$here/tab-status.lua" "$LUA"
else
  curl -fsSL "https://raw.githubusercontent.com/$REPO/$REF/tab-status.lua" -o "$LUA" || die "couldn't download tab-status.lua"
fi
ok "installed $LUA"

strip_config
{
  echo "$BEGIN"
  echo 'require("tab-status")'
  [ -z "$KEY" ] || echo "rex.bind(\"$KEY\", \"tab_seen_toggle\")"
  echo "$END"
} >>"$CONFIG"
"$REX" config check >/dev/null || die "init.lua has errors after the change; run: rex config check"
"$REX" config reload >/dev/null
if [ -n "$KEY" ]; then ok "bound $KEY to Toggle Tab Seen"; else ok "added Toggle Tab Seen (no key; find it in the command palette)"; fi

stop_agent
cat >"$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key><string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>$REX</string>
    <string>do</string>
    <string>$LUA</string>
    <string>--all</string>
  </array>
  <key>EnvironmentVariables</key>
  <dict>
    <key>XDG_STATE_HOME</key><string>$(dirname "$STATE")</string>
  </dict>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>ThrottleInterval</key><integer>10</integer>
  <key>StandardOutPath</key><string>$LOG</string>
  <key>StandardErrorPath</key><string>$LOG</string>
</dict>
</plist>
EOF
: >"$LOG"
launchctl bootstrap "$DOMAIN" "$PLIST"
ok "installed launchd agent (starts at login)"

i=0
until grep -q '^listening' "$LOG" 2>/dev/null; do
  i=$((i + 1))
  [ $i -le 20 ] || die "the listener didn't start; see $LOG"
  sleep 0.5
done
ok "listening to every Rex session"

# Claude Code, Codex and OpenCode report their state on their own. Gemini CLI needs hooks,
# which ship in this repo as a Gemini extension.
if command -v gemini >/dev/null 2>&1; then
  # --ref only applies to a git URL, not to a clone's path.
  if [ -n "$here" ]; then set -- "$here"; else set -- "https://github.com/$REPO" --ref "$REF"; fi
  gemini extensions uninstall rex-tab-status >/dev/null 2>&1 || true
  if gemini extensions install "$@" --consent >/dev/null 2>&1; then
    ok "installed the Gemini CLI extension"
  else
    warn "couldn't install the Gemini CLI extension; run: gemini extensions install $*"
  fi
fi

echo
echo "  ⏳ working  ✋ approve  ❓ question  🔑 login  ❌ error  ✅ unread"
[ -z "$KEY" ] || echo "  $KEY marks the current tab seen or unseen."
echo "  Uninstall: rerun with --uninstall"
