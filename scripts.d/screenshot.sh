#!/usr/bin/env bash

# Configuration
SCREENSHOT_DIR="${XDG_PICTURES_DIR:-$HOME/Pictures/Screenshots}"
DEFAULT_MODE="region"  # region, output, window
QUALITY=100
DELAY=0
NOTIFY_TIMEOUT=5000
EDITOR="gimp"
CLIPBOARD=true
OPEN_AFTER=false

mkdir -p "$SCREENSHOT_DIR"

# Flags
MODE="$DEFAULT_MODE"
SAVE=true
EDIT=false
DEBUG=false

log() {
  [ "$DEBUG" = true ] && echo "[DEBUG] $1" >&2
}

error() {
  echo "[ERROR] $1" >&2
  notify-send -t "$NOTIFY_TIMEOUT" "❌ Screenshot Error" "$1"
}

help() {
  cat <<EOF
Usage: $0 [options]
  -m, --mode MODE        Screenshot mode: region, output, window
  -c, --clipboard        Clipboard only
  -s, --save             Save only (no clipboard)
  -e, --edit             Open in editor after screenshot
  -o, --open             Open image after screenshot
  -d, --delay SECS       Delay in seconds before taking screenshot
  -q, --quality NUM      Quality (1-100)
  --debug                Enable debug output
  -h, --help             Show this help
EOF
  exit 0
}

# Parse arguments
while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--mode) MODE="$2"; shift 2;;
    -c|--clipboard) SAVE=false; CLIPBOARD=true; shift;;
    -s|--save) SAVE=true; CLIPBOARD=false; shift;;
    -e|--edit) EDIT=true; shift;;
    -o|--open) OPEN_AFTER=true; shift;;
    -d|--delay) DELAY="$2"; shift 2;;
    -q|--quality) QUALITY="$2"; shift 2;;
    --debug) DEBUG=true; shift;;
    -h|--help) help;;
    *) echo "Unknown option: $1"; help;;
  esac
done

# Validate dependencies
command -v hyprshot >/dev/null || { error "hyprshot not found"; exit 1; }
$CLIPBOARD && ! command -v wl-copy >/dev/null && CLIPBOARD=false

# Optional delay
[ "$DELAY" -gt 0 ] && { notify-send "Screenshot" "In ${DELAY}s..."; sleep "$DELAY"; }

# Take screenshot
if $SAVE; then
  OUTPUT=$(hyprshot -m "$MODE" -o "$SCREENSHOT_DIR" -z --quality "$QUALITY" 2>&1)
  EXIT_CODE=$?

  if [ $EXIT_CODE -eq 130 ]; then
    log "Screenshot canceled by user"
    exit 0
  elif [ $EXIT_CODE -ne 0 ]; then
    error "hyprshot failed: $OUTPUT"
    exit 1
  fi

  FILE=$(echo "$OUTPUT" | grep -oP 'Screenshot saved to: \K.*')
  [ ! -f "$FILE" ] && FILE=$(find "$SCREENSHOT_DIR" -type f -printf "%T@ %p\n" | sort -n | tail -1 | cut -d' ' -f2-)

  $CLIPBOARD && wl-copy < "$FILE"
  notify-send -t "$NOTIFY_TIMEOUT" -i "$FILE" "📸 Screenshot saved" "$FILE"

  $EDIT && command -v "$EDITOR" >/dev/null && "$EDITOR" "$FILE" &
  $OPEN_AFTER && xdg-open "$FILE" &
else
  hyprshot -m "$MODE" -z --quality "$QUALITY" --clipboard-only
  EXIT_CODE=$?
  if [ $EXIT_CODE -eq 130 ]; then
    log "Screenshot canceled by user"
    exit 0
  elif [ $EXIT_CODE -ne 0 ]; then
    error "Screenshot failed"
    exit 1
  fi
  notify-send -t "$NOTIFY_TIMEOUT" "📋 Screenshot copied" "Screenshot copied to clipboard"
fi

exit 0