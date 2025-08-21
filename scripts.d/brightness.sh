#!/usr/bin/env bash

# Usage: ddc-brightness.sh up|down [bus_id ...]
# Example: ddc-brightness.sh up 4 6 7

STEP=10
ACTION=$1
shift

# If no buses passed, default to common ones
BUSES=("$@")
[[ ${#BUSES[@]} -eq 0 ]] && BUSES=(2 3)

for bus in "${BUSES[@]}"; do
  if [[ "$ACTION" == "up" ]]; then
    ddcutil --noconfig --sleep-multiplier=0 --bus=$bus setvcp 10 + $STEP
  elif [[ "$ACTION" == "down" ]]; then
    ddcutil --noconfig --sleep-multiplier=0 --bus=$bus setvcp 10 - $STEP
  fi
done