#!/usr/bin/bash

# SwayNC Quick Settings Script
# Usage: ~/.config/swaync/qs.sh [query|toggle] [name]

function command_exists {
  command -v "${1}" > /dev/null 2>&1
}

function qs::darkmode::query {
  if ! command_exists dconf; then
    echo "false"
    return 1
  fi

  local status
  read -r status < <(dconf read /org/gnome/desktop/interface/color-scheme)
  [[ "${status}" =~ "dark" ]] && echo "true" || echo "false"
}

function qs::darkmode::toggle {
  if ! command_exists dconf; then
    notify-send "Appearance" "dconf not found, cannot toggle dark mode" -i dialog-error
    return 1
  fi

  local mode
  read -r mode < <(dconf read /org/gnome/desktop/interface/color-scheme)

  if [[ "${mode}" =~ "dark" ]]; then
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-light'"
    notify-send "Appearance" "Dark mode disabled" -i weather-clear
  else
    dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'"
    notify-send "Appearance" "Dark mode enabled" -i weather-clear-night
  fi
}

function qs::wifi::query {
  local status
  read -r status < <(nmcli radio wifi)
  [[ "${status}" == "enabled" ]] && echo "true" || echo "false"
}

function qs::wifi::toggle {
  local status
  read -r status < <(nmcli radio wifi)
  if [[ "${status}" == "enabled" ]]; then
    nmcli radio wifi off
    notify-send "WiFi" "WiFi disabled" -i network-wireless-offline
  else
    nmcli radio wifi on
    notify-send "WiFi" "WiFi enabled" -i network-wireless-signal-excellent
  fi
}

function qs::bluetooth::query {
  if command_exists bluetoothctl; then
    local status
    read -r _ status < <(bluetoothctl show | grep "Powered:")
    [[ "${status}" == "yes" ]] && echo "true" || echo "false"
  else
    echo "false"
  fi
}

function qs::bluetooth::toggle {
  if command_exists bluetoothctl; then
    local status
    read -r _ status < <(bluetoothctl show | grep "Powered:")
    if [[ "${status}" == "yes" ]]; then
      bluetoothctl power off && {
        command_exists blueman-applet && pgrep blueman-applet &> /dev/null && {
          pkill --signal SIGINT blueman-applet
        }
      }
      notify-send "Bluetooth" "Bluetooth disabled" -i bluetooth-disabled
    else
      if rfkill -no SOFT list bluetooth | grep -q blocked; then
        rfkill unblock bluetooth || {
          notify-send "Error" "Bluetooth unlock failed" -i dialog-error
          return
        }
      fi
      # shellcheck disable=SC2015
      if ! bluetoothctl power on; then
        notify-send "Bluetooth" "Bluetooth enabled" -i bluetooth-active
        command_exists blueman-applet && blueman-applet &> /dev/null &
      else
        notify-send "Bluetooth" "Failed to enable Bluetooth" -i dialog-error
      fi
    fi
  else
    notify-send "Error" "Bluetooth not available" -i dialog-error
  fi
}

function qs::dnd::query {
  if command_exists swaync-client; then
    swaync-client -D
  else
    echo "false"
  fi
}

function qs::dnd::toggle {
  if command_exists swaync-client; then
    local current
    read -r current < <(swaync-client -D)
    if [[ "${current}" == "true" ]]; then
      notify-send "Do Not Disturb" "Do Not Disturb disabled" -i notification-new
      swaync-client -df -sw
    else
      notify-send "Do Not Disturb" "Do Not Disturb enabled" -i notification-disabled
      swaync-client -dn -sw
    fi
  else
    notify-send "Error" "SwayNC not available" -i dialog-error
  fi
}

function __get_nightlight_tool {
  local temp="${1}"
  local -n ref_ca_command="${2}"

  if command_exists hyprsunset; then
    ref_ca_command=("hyprsunset" "-t" "${temp}")
  elif command_exists wlsunset; then
    ref_ca_command=("wlsunset" "-T" "${temp}")
  elif command_exists gammastep; then
    ref_ca_command=("gammastep" "-O" "${temp}")
  else
    notify-send "Error" "No night light tool available" -i dialog-error
    exit
  fi

  return 0
}

function qs::nightlight::query {
  local -a ca_command=()
  __get_nightlight_tool 4500 ca_command

  if pgrep -x "${ca_command[0]}" > /dev/null; then
    echo "true"
  else
    echo "false"
  fi
}

function qs::nightlight::toggle {
  local -a ca_command=()
  __get_nightlight_tool 4500 ca_command

  local current
  read -r current < <(qs::nightlight::query)

  if [[ "${current}" == "true" ]]; then
    pkill -x "${ca_command[0]}"
    notify-send "Night Light" "Night Light disabled" -i weather-clear
  else
    "${ca_command[@]}" &
    notify-send "Night Light" "Night Light enabled" -i weather-clear-night
  fi
}

function qs::airplane::query {
  local wifi_status bluetooth_status
  read -r wifi_status < <(nmcli radio wifi)
  read -r _ bluetooth_status < <(bluetoothctl show | grep "Powered:")
  if [[ "${wifi_status}" == "disabled" ]] && [[ "${bluetooth_status}" == "no" ]]; then
    echo "true"
  else
    echo "false"
  fi
}

function qs::airplane::toggle {
  local current
  read -r current < <(qs::airplane::query)
  if [[ "${current}" == "true" ]]; then
    nmcli radio wifi on
    bluetoothctl power on 2> /dev/null
    notify-send "Airplane Mode" "Airplane Mode disabled" -i airplane-mode-off
  else
    nmcli radio wifi off
    bluetoothctl power off 2> /dev/null
    notify-send "Airplane Mode" "Airplane Mode enabled" -i airplane-mode
  fi
}

function qs::autorotate::query {
  # This would depend on your auto-rotate implementation
  # For now, return false
  echo "false"
}

function qs::autorotate::toggle {
  notify-send "Auto Rotate" "Auto Rotate toggled" -i screen-rotation
}

function qs::vpn::query {
  if command_exists nmcli; then
    local vpn_status
    read -r vpn_status < <(nmcli con show --active | grep -c vpn)
    ((vpn_status > 0)) && echo "true" || echo "false"
  else
    echo "false"
  fi
}

function qs::vpn::toggle {
  local current
  read -r current < <(qs::vpn::query)
  if [[ "${current}" == "true" ]]; then
    local vpn_name
    read -r vpn_name _ < <(nmcli con show --active | grep vpn)
    nmcli con down id "${vpn_name}"
    notify-send "VPN" "VPN disconnected" -i network-vpn-disconnected
  else
    local vpn_name
    read -r vpn_name _ < <(nmcli con show | grep vpn | head -1)
    if [[ -n "${vpn_name}" ]]; then
      nmcli con up id "${vpn_name}"
      notify-send "VPN" "VPN connected" -i network-vpn
    else
      notify-send "VPN" "No VPN connections configured" -i dialog-error
    fi
  fi
}

function qs::hotspot::query {
  if command_exists nmcli; then
    local hotspot_status
    read -r hotspot_status < <(nmcli con show --active | grep -c hotspot)
    ((hotspot_status > 0)) && echo "true" || echo "false"
  else
    echo "false"
  fi
}

function qs::hotspot::toggle {
  local current
  read -r current < <(qs::hotspot::query)
  if [[ "${current}" == "true" ]]; then
    nmcli con down Hotspot 2> /dev/null
    notify-send "Hotspot" "Hotspot disabled" -i network-wireless-hotspot-off
  else
    nmcli dev wifi hotspot
    notify-send "Hotspot" "Hotspot enabled" -i network-wireless-hotspot
  fi
}

function qs::screenrecord::toggle {
  if pgrep -x "wf-recorder" > /dev/null; then
    pkill -x wf-recorder
    notify-send "Screen Record" "Recording stopped" -i media-record
  else
    local timestamp
    read -r timestamp < <(date +%Y%m%d-%H%M%S)
    mkdir -p ~/Videos
    wf-recorder -f ~/Videos/recording-"${timestamp}".mp4 &
    notify-send "Screen Record" "Recording started" -i media-record
  fi
}

function qs::screenshot::toggle {
  if command_exists grim && command_exists slurp; then
    local timestamp selection
    read -r timestamp < <(date +%Y%m%d-%H%M%S)
    read -r selection < <(slurp)
    grim -g "${selection}" ~/Pictures/screenshot-"${timestamp}".png
    notify-send "Screenshot" "Screenshot saved" -i camera-photo
  elif command_exists gnome-screenshot; then
    gnome-screenshot -a
    notify-send "Screenshot" "Screenshot saved" -i camera-photo
  else
    notify-send "Error" "No screenshot tool available" -i dialog-error
  fi
}

function qs::powermenu::toggle {
  if command_exists wlogout; then
    wlogout
  elif command_exists rofi; then
    local choice
    read -r choice < <(echo -e "⏻ Shutdown\n⏾ Suspend\n⟲ Reboot\n⇠ Logout" | rofi -dmenu -p "Power Menu")
    case "${choice}" in
      "⏻ Shutdown") systemctl poweroff ;;
      "⏾ Suspend") systemctl suspend ;;
      "⟲ Reboot") systemctl reboot ;;
      "⇠ Logout") hyprctl dispatch exit ;;
    esac
  else
    notify-send "Error" "No power menu tool available" -i dialog-error
  fi
}

function qs::settings::toggle {
  if command_exists gnome-control-center; then
    gnome-control-center &
  elif command_exists systemsettings5; then
    systemsettings5 &
  elif command_exists xfce4-settings-manager; then
    xfce4-settings-manager &
  else
    notify-send "Error" "No settings app available" -i dialog-error
  fi
}

function main {
  local action="${1}"
  local name="${2}"

  if [[ -z "${action}" ]] || [[ -z "${name}" ]]; then
    echo "Usage: ${0} [query|toggle] [name]"
    echo "Available functions:"
    declare -F | grep "^declare -f qs::" | sed 's/declare -f qs::/  ➜ /'
    exit 1
  fi

  local func_name="qs::${name}::${action}"

  if ! declare -F "${func_name}" &> /dev/null; then
    echo "Error: Function '${func_name}' not found"
    echo "Available functions:"
    declare -F | grep "^declare -f qs::" | sed 's/declare -f qs::/  ➜ /'
    exit 1
  fi

  eval "${func_name}"
}

main "${@}"
