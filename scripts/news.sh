#!/bin/bash
# Fetches top news headlines from configured sources.
# Called by marquee.sh when NEWS_MODE is enabled.
# Configure sources in ~/.tmux/marquee.conf

CONF="/home/kiran/.tmux/marquee.conf"
CACHE="/tmp/tmux-news"
NEWS_COUNT=3
NEWS_SOURCES="hackernews"
REFRESH_MIN=15

[ -f "$CONF" ] && source "$CONF"

# Override count from arg if provided
[ -n "$1" ] && NEWS_COUNT="$1"

# Only fetch if cache is missing or stale
if [ -f "$CACHE" ] && [ -z "$(find "$CACHE" -mmin +${REFRESH_MIN} 2>/dev/null)" ]; then
  exit 0
fi

# Generic RSS feed parser
fetch_rss() {
  local url="$1"
  local count="$2"
  curl -m 5 -s "$url" 2>/dev/null | python3 -c "
import sys, xml.etree.ElementTree as ET
try:
    root = ET.parse(sys.stdin).getroot()
    for item in root.findall('.//item')[:${count}]:
        title = item.find('title')
        if title is not None and title.text:
            print(title.text.strip())
except: pass
" 2>/dev/null
}

# Hacker News JSON API fetcher
fetch_hackernews() {
  local count="$1"
  local ids
  ids=$(curl -m 3 -s 'https://hacker-news.firebaseio.com/v0/topstories.json' 2>/dev/null)
  [ -z "$ids" ] && return
  for id in $(echo "$ids" | python3 -c "import sys,json; [print(i) for i in json.load(sys.stdin)[:${count}]]" 2>/dev/null); do
    curl -m 2 -s "https://hacker-news.firebaseio.com/v0/item/${id}.json" 2>/dev/null \
      | python3 -c "import sys,json; t=json.load(sys.stdin).get('title',''); t and print(t)" 2>/dev/null
  done
}

# Source URL map
get_source_url() {
  case "$1" in
    bbc-world)   echo "https://feeds.bbci.co.uk/news/world/rss.xml" ;;
    bbc-tech)    echo "https://feeds.bbci.co.uk/news/technology/rss.xml" ;;
    aljazeera)   echo "https://www.aljazeera.com/xml/rss/all.xml" ;;
    google)      echo "https://news.google.com/rss?hl=en-US&gl=US&ceid=US:en" ;;
    google-tech) echo "https://news.google.com/rss/search?q=technology&hl=en-US&gl=US&ceid=US:en" ;;
    npr)         echo "https://feeds.npr.org/1001/rss.xml" ;;
    techcrunch)  echo "https://techcrunch.com/feed/" ;;
    *)           echo "" ;;
  esac
}

# Fetch from all configured sources
HEADLINES=""
for src in $NEWS_SOURCES; do
  if [ "$src" = "hackernews" ]; then
    result=$(fetch_hackernews "$NEWS_COUNT")
  else
    url=$(get_source_url "$src")
    [ -z "$url" ] && continue
    result=$(fetch_rss "$url" "$NEWS_COUNT")
  fi
  [ -n "$result" ] && HEADLINES+="${result}"$'\n'
done

[ -n "$HEADLINES" ] && printf '%s' "$HEADLINES" > "$CACHE"
