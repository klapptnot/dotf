#!/usr/bin/bash

declare -A ignore_map=(
  [Hyprland]='\.config/hypr'
  [swaync]='\.config/swaync'
  [waybar]='\.config/waybar'
  [wlogout]='\.config/wlogout'
  [kitty]='\.config/kitty'

  [nu]='\.config/nushell'
  [fish]='\.config/fish'
  [zsh]='\.zshrc$'

  [hx]='\.config/helix'
  [clangd]='\.config/clangd'

  [mpv]='\.config/mpv'
  [ghostty]='\.config/ghostty'
  [bat]='\.config/bat'
)

for cmd in "${!ignore_map[@]}"; do
  command -v "${cmd}" > /dev/null || printf '^%s\n' "${ignore_map[${cmd}]}"
done
