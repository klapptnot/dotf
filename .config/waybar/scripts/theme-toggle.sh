#!/usr/bin/env bash
# waybar-theme-toggle.sh - Toggle GNOME dark/light mode for Waybar

set -euo pipefail

readonly DCONF_PATH="/org/gnome/desktop/interface/color-scheme"
readonly ICON_DARK="󰖔"  # Moon icon (nerd font)
readonly ICON_LIGHT=""  # Sun icon (nerd font)

function get_current_mode {
  local mode
  read -r mode < <(dconf read "${DCONF_PATH}" 2>/dev/null || echo "'default'")

  if [[ "${mode}" =~ "dark" ]]; then
    echo "dark"
  else
    echo "light"
  fi
}

function toggle_mode {
  local current
  read -r current < <(get_current_mode)

  if [[ "${current}" == "dark" ]]; then
    dconf write "${DCONF_PATH}" "'prefer-light'" \
      || notify-send "Appearance" "Dark mode could not be disabled" -i weather-clear-night
  else
    dconf write "${DCONF_PATH}" "'prefer-dark'" \
      || notify-send "Appearance" "Dark mode could not be enabled" -i weather-clear
  fi
}

function output_waybar_json {
  local mode icon tooltip
  read -r mode < <(get_current_mode)

  if [[ "${mode}" == "dark" ]]; then
    icon="${ICON_DARK}"
    tooltip="Dark mode (click to switch to light)"
  else
    icon="${ICON_LIGHT}"
    tooltip="Light mode (click to switch to dark)"
  fi

  printf '{"text": "%s", "tooltip": "%s", "class": "%s"}\n' \
    "${icon}" "${tooltip}" "${mode}"
}

function main {
  if ! command -v dconf &>/dev/null; then
    printf '{"text": "󰅙", "tooltip": "dconf not available", "class": "error"}\n'
    return 1
  fi

  case "${1:-status}" in
    toggle)
      toggle_mode
      ;;
    status|*)
      output_waybar_json
      ;;
  esac
}

main "${@}"
