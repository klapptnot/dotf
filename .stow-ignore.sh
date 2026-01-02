#!/usr/bin/bash

# Desktop environment
command -v Hyprland > /dev/null || printf '^\.config/hypr.*\n'
command -v swaync > /dev/null || printf '^\.config/swaync.*\n'
command -v waybar > /dev/null || printf '^\.config/waybar.*\n'
command -v wlogout > /dev/null || printf '^\.config/wlogout.*\n'
command -v kitty > /dev/null || printf '^\.config/kitty.*\n'

# Shell
command -v nu > /dev/null || printf '^\.config/nushell.*\n'
command -v fish > /dev/null || printf '^\.config/fish.*\n'
command -v zsh > /dev/null || printf '^\.zshrc$\n'
command -v bat > /dev/null || printf '^\.config/bat.*\n'
