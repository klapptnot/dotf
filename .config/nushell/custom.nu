# 🔗 https://github.com/klapptnot/dotf

for kv in (open ~/.config/dotf/props.yaml | get shell_environment | transpose key val) {
  if ($kv.val | str starts-with '$ ') {
    load-env { $kv.key: (bash -c ($kv.val | str substring 2..)) }
  } else {
    load-env { $kv.key: $kv.val }
  }
}

# binding: revert last Ctrl+Z freezing
def __unfreeze_last_app []: nothing -> nothing {
  let frozen  = job list | where type == frozen | last

  if $frozen != null {
    job unfreeze $frozen.id
  }
}

# binding: select file ➜ nvim
def __open_file_nvim []: nothing -> nothing {
  let f = (
    tv
    --source-command $env.FIND_FILE_COMMAND
    --cache-preview
    --select-1
    --preview-command "bat --style=numbers --color=always --line-range=:500 '{}'"
    --preview-size 65
    --preview-border rounded
    --preview-word-wrap
    --input-position top
    --results-border rounded
    --input-border rounded
    --layout landscape
    --hide-help-panel
    --hide-status-bar
    | lines
  )
  if ($f | length) > 0 { nvim ...($f | str trim) }
}

# use python http server (wrapper function)
def --wrapped serve-http [...rest]: nothing -> nothing {
  python -m http.server ...$rest
}

# get your network public IP address
def get-ip []: nothing -> nothing {
  http get --headers ['user-agent' 'curl'] ifconfig.me
}

alias uwu = sudo
alias wdc = windscribe-cli
alias snek = python
alias nano = vim
alias lg = lazygit
alias git = git --no-pager
alias systemctl = systemctl --no-pager

source ~/.config/nushell/scripts/compsrc.nu   # All completion sources
source ~/.config/nushell/scripts/mirkop.nu    # Prompt functions
