#!/bin/sh
# Report an agent's state to Rex with OSC 7501, for agents that don't report it themselves.
# Gemini CLI runs this from hooks/hooks.json. Usage: report.sh APP STATE [KIND]
cat >/dev/null # hooks send JSON on stdin; nothing here needs it

# Hooks run without a terminal of their own, so write to the first ancestor's terminal.
tty= p=$PPID
while [ "${p:-1}" -gt 1 ]; do
  t=$(ps -o tty= -p "$p" 2>/dev/null | tr -d ' ')
  case $t in '' | '?' | '??') p=$(ps -o ppid= -p "$p" 2>/dev/null | tr -d ' ') ;; *) tty=/dev/$t; break ;; esac
done

if [ -n "$tty" ] && [ -w "$tty" ]; then
  printf '\033]7501;state=%s:app=%s%s\033\\' "$2" "$1" "${3:+:kind=$3}" > "$tty"
fi
echo '{}' # Gemini CLI parses stdout as JSON
