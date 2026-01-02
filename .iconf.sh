#!/usr/bin/bash
# shellcheck disable=SC2034

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Break execution
  printf "[\x1b[38;05;9m*\x1b[00m] This script is not made to run as a normal script\n"
  exit 1
fi

function post_install {
  : "${HOME:?HUH!?}"
  [ -e "${HOME}/.geoinfo" ] || {
    [ -z "${INSTALL_USER_GEOINFO}" ] && log w "No geographic info given, leaving empty"
    echo "${INSTALL_USER_GEOINFO}" > "${HOME}/.geoinfo"
  }

  local -ra needed_folders=(
    "${HOME}/.cache/hyprland"
    "${HOME}/.cache/carapace"
  )

  mkdir -p "${needed_folders[@]}"

  command -v hyprlock &> /dev/null && {
    # Toggle file for medialock
    local m_f_c=(
      "#__medialock__"
      "source = ~/.config/hypr/conf.d/medialock.conf"
    )
    printf '%s\n' "${m_f_c[@]}" > ~/.cache/hyprland/medialock.conf
  }

  command -v carapace &> /dev/null && {
    command -v fish &> /dev/null && carapace _carapace fish > ~/.cache/carapace/init.fish
    command -v zsh &> /dev/null && carapace _carapace zsh > ~/.cache/carapace/init.zsh
    command -v bash &> /dev/null && carapace _carapace bash > ~/.cache/carapace/init.bash
  }
  command -v bat &> /dev/null && bat cache --build &> /dev/null
}

function post_remove {
  : "${HOME:?Why did this fail?}"
  [ -e "${HOME}/.geoinfo" ] && rm -f "${HOME}/.geoinfo"

  local -ra needed_folders=(
    "${HOME}/.cache/hyprland"
    "${HOME}/.cache/carapace"
  )

  rm -fr "${needed_folders[@]}"

  rm -f ~/.cache/hyprland/medialock.conf \
    ~/.cache/carapace/init.fish \
    ~/.cache/carapace/init.zsh \
    ~/.cache/carapace/init.bash
}

pacman_pkgs=(
  base
  base-devel
  bat
  blueman
  bluez-utils
  brightnessctl
  efibootmgr
  fastfetch
  fd
  flatpak
  fzf
  git
  github-cli
  gnome-control-center
  gnome-settings-daemon
  grim
  htop
  hypridle
  hyprland
  hyprlock
  hyprpaper
  hyprpicker
  jq
  kitty
  loupe
  mpv
  neovim
  nodejs
  npm
  ntfs-3g
  nushell
  papirus-icon-theme
  python-pip
  python-pipx
  ripgrep
  slurp
  swaync
  thunar
  ttf-cascadia-code-nerd
  tumbler
  vivid
  waybar
  wget
  yad
  zip
)

yay_pkgs=(
  vicinae
  carapace-bin
  ttf-twemoji-color
  catppuccin-gtk-theme-mocha
  wlogout
)
