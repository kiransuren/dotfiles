#!/bin/bash
# Tmux marquee engine
# Modes: text (marquee.txt), news (live headlines), graphic (ASCII sprite)
# Configure via ~/.tmux/marquee.conf

CONF="/home/kiran/.tmux/marquee.conf"
MSGS="/home/kiran/.tmux/marquee.txt"
GRAPHICS_DIR="/home/kiran/.tmux/graphics"
NEWS_SCRIPT="/home/kiran/.tmux/news.sh"
NEWS_CACHE="/tmp/tmux-news"
SPEED=1
PADDING=10
NEWS_MODE=off
NEWS_COUNT=3
MARQUEE_MODE=graphic
GRAPHIC="race-car"
GRAPHIC_BG="_"

[ -f "$CONF" ] && source "$CONF"

WIDTH=$(tmux display-message -p '#{pane_width}' 2>/dev/null || echo 160)

# --- Graphic mode ---
if [ "$MARQUEE_MODE" = "graphic" ]; then
  SPRITE_FILE="${GRAPHICS_DIR}/${GRAPHIC}.txt"
  if [ ! -f "$SPRITE_FILE" ]; then
    printf '%*s' "$WIDTH" ''
    exit 0
  fi
  SPRITE=$(head -1 "$SPRITE_FILE" | tr -d '\n')
  SLEN=${#SPRITE}
  CYCLE=$(( WIDTH + SLEN ))
  POS=$(( ($(date +%s) * SPEED) % CYCLE ))
  COL=$(( POS - SLEN ))

  # Build background fill
  BG=""
  for (( i=0; i<WIDTH; i++ )); do BG+="$GRAPHIC_BG"; done
  BG="${BG:0:$WIDTH}"

  LINE="$BG"

  if (( COL >= 0 && COL + SLEN <= WIDTH )); then
    LINE="${LINE:0:$COL}${SPRITE}${LINE:$((COL + SLEN))}"
  elif (( COL < 0 && COL + SLEN > 0 )); then
    VISIBLE="${SPRITE:$(( -COL ))}"
    LINE="${VISIBLE}${LINE:${#VISIBLE}}"
  elif (( COL >= 0 && COL < WIDTH )); then
    VISIBLE="${SPRITE:0:$((WIDTH - COL))}"
    LINE="${LINE:0:$COL}${VISIBLE}"
  fi

  printf '%s' "$LINE"
  exit 0
fi

# --- Text / News mode ---
[ "$MARQUEE_MODE" = "news" ] && NEWS_MODE=on
if [ "$NEWS_MODE" = "on" ]; then
  bash "$NEWS_SCRIPT" "$NEWS_COUNT" &>/dev/null &
  if [ -f "$NEWS_CACHE" ]; then
    SRC="$NEWS_CACHE"
  else
    SRC="$MSGS"
  fi
else
  SRC="$MSGS"
fi

mapfile -t LINES < <(grep -v '^$' "$SRC" 2>/dev/null)
COUNT=${#LINES[@]}
if (( COUNT == 0 )); then
  printf '%*s' "$WIDTH" ''
  exit 0
fi

PAD=$(printf '%*s' "$PADDING" '')
TAPE=""
for (( i=0; i<COUNT; i++ )); do
  TAPE+="${LINES[$i]}${PAD}"
done
TAPELEN=${#TAPE}

POS=$(( ($(date +%s) * SPEED) % TAPELEN ))

DOUBLED="${TAPE}${TAPE}"
WINDOW="${DOUBLED:$POS:$WIDTH}"

printf '%s' "$WINDOW"
