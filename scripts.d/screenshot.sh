#!/bin/bash
set -euo pipefail

DATE_DIR="$(date +%Y-%m-%d)"
TIME_NOW="$(date +%H-%M-%S)"
SAVE_DIR="${XDG_SCREENSHOTS_DIR:-${XDG_PICTURES_DIR:-$HOME/Pictures}/Screenshots}/$DATE_DIR"
FILENAME="Screenshot_$TIME_NOW.png"
LOGFILE="$SAVE_DIR/screenshot.log"

MODE="region"
COPY="true"

print_help() {
    cat <<EOF
Usage: screenshot [mode] [options]

Modes:
  region        Capture a selected region (default)
  window        Capture the active window
  full          Capture the entire screen

Options:
  --no-clipboard    Do not copy screenshot to clipboard
  -h, --help        Show this help message

Example:
  screenshot full --no-clipboard
EOF
}

take_screenshot() {
    mkdir -p "$SAVE_DIR"

    hyprshot -z -m $MODE -o "$SAVE_DIR" -f "$FILENAME" 

    echo "$(date): Saved $SAVE_DIR/$FILENAME" >> "$LOGFILE"
}

while [[ $# -gt 0 ]]; do
    case "$1" in
        region|window|full|fullscreen)
            MODE="${1/full/full}"
            MODE="${MODE/fullscreen/full}"
            shift
            ;;
        --no-clipboard)
            COPY="false"
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "❌ Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

take_screenshot