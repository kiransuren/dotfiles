#!/bin/bash
CACHE="/tmp/tmux-weather"
if [ ! -f "$CACHE" ] || [ "$(find "$CACHE" -mmin +5 2>/dev/null)" ]; then
  result=$(curl -m 1 'wttr.in/Atlanta?format=3&m' 2>/dev/null | sed "s/$(printf '\xef\xb8\x8f')//g" | sed 's/  */ /g')
  [ -n "$result" ] && printf '%s' "$result" > "$CACHE"
fi
cat "$CACHE" 2>/dev/null
