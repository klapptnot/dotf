#!/usr/bin/bash
# 🔗 https://github.com/klapptnot/dotf

function main {
  # Check if wlogout is already running
  if pgrep -x "wlogout" > /dev/null; then
    pkill -x "wlogout"
    exit 0
  fi

  wlogout \
    --layout "${HOME}/.config/wlogout/layout" \
    --css "${HOME}/.config/wlogout/style.css" \
    --protocol layer-shell \
    --buttons-per-row 3 &
}

main "${@}"
