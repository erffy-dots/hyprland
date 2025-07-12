#!/usr/bin/env bash

## Author: Aditya Shakya, Gonçalo Duarte

set -e

prompt='Screenshot'
mesg="DIR: $XDG_SCREENSHOTS_DIR"

# Screenshot types
option_capture_1="screen"
option_capture_2="output"
option_capture_3="area"

# Defaults
countdown=0
option_type_screenshot=""
actions=()

# Function: Countdown Timer
timer() {
  if [[ $countdown -gt 10 ]]; then
    notify-send -t 1000 "Taking Screenshot in ${countdown} seconds"
    sleep $((countdown - 10))
    countdown=10
  fi
  while [[ $countdown -ne 0 ]]; do
    notify-send -t 1000 "Taking Screenshot in ${countdown}"
    countdown=$((countdown - 1))
    sleep 1
  done
}

# Function: Take Screenshot and apply actions
takescreenshot() {
  [[ $countdown -gt 0 ]] && timer

  tempfile="/tmp/screenshot_$(date +%s).png"
  grimblast save "$option_type_screenshot" "$tempfile"

  for action in "${actions[@]}"; do
    case "$action" in
      copy)
        wl-copy < "$tempfile"
        ;;
      save)
        mkdir -p $XDG_SCREENSHOTS_DIR
        cp "$tempfile" $XDG_SCREENSHOTS_DIR/Screenshot_$(date +%Y-%m-%d_%H-%M-%S).png
        ;;
      edit)
        ${EDITOR:-imv} "$tempfile"
        ;;
    esac
  done
}

# Parse CLI Arguments
parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
      --screen) option_type_screenshot="$option_capture_1" ;;
      --output) option_type_screenshot="$option_capture_2" ;;
      --area) option_type_screenshot="$option_capture_3" ;;
      --copy) actions+=("copy") ;;
      --save) actions+=("save") ;;
      --edit) actions+=("edit") ;;
      --delay)
        shift
        [[ $1 =~ ^[0-9]+$ ]] && countdown=$1 || { echo "Invalid delay value"; exit 1; }
        ;;
      -h|--help)
        echo "Usage: screenshot.sh [--screen|--output|--area] [--copy] [--save] [--edit] [--delay N]"
        echo
        echo "If no arguments are passed, Rofi UI will be shown."
        exit 0
        ;;
      *)
        echo "Unknown option: $1"
        exit 1
        ;;
    esac
    shift
  done
}

# Rofi fallback UI
fallback_rofi() {
  # Helper for rofi menu
  rofi_cmd() {
    rofi -theme-str "window {width: 400px;}" \
      -theme-str "listview {columns: 1; lines: 2;}" \
      -dmenu -p "$prompt" -mesg "$mesg" -markup-rows
  }

  # Screenshot type menu
  type_screenshot_cmd() {
    echo -e "󰍺 All Screen\n󰍹 Active Screen\n󱣴 Area" | rofi -theme-str 'window {width: 400px;}' \
      -dmenu -p 'Screenshot Type' -mesg 'Choose:'
  }

  # Copy/Save menu
  copy_save_cmd() {
    echo -e " Copy\n Save\nCopy & Save\nEdit Screenshot" | rofi -theme-str 'window {width: 400px;}' \
      -dmenu -p 'Action' -mesg 'Choose:'
  }

  # Timer menu
  timer_cmd() {
    echo -e "0\n5\n10\n20\n30\n60" | rofi -theme-str 'window {width: 400px;}' \
      -dmenu -p 'Delay (seconds)' -mesg 'Optional delay:'
  }

  chosen="$(echo -e "󰹑 Capture\n󰁫 Timer Capture" | rofi_cmd)"
  [[ "$chosen" == "󰁫 Timer Capture" ]] && countdown="$(timer_cmd)"

  type="$(type_screenshot_cmd)"
  [[ "$type" == "󰍺 All Screen" ]] && option_type_screenshot="screen"
  [[ "$type" == "󰍹 Active Screen" ]] && option_type_screenshot="output"
  [[ "$type" == "󱣴 Area" ]] && option_type_screenshot="area"

  action="$(copy_save_cmd)"
  case "$action" in
    " Copy") actions=("copy") ;;
    " Save") actions=("save") ;;
    "Copy & Save") actions=("copy" "save") ;;
    "Edit Screenshot") actions=("edit") ;;
  esac
}

# Entry Point
main() {
  if [[ $# -eq 0 ]]; then
    fallback_rofi
  else
    parse_args "$@"
  fi

  if [[ -z "$option_type_screenshot" || ${#actions[@]} -eq 0 ]]; then
    echo "Error: Screenshot type or action missing. Use --help"
    exit 1
  fi

  takescreenshot
}

main "$@"