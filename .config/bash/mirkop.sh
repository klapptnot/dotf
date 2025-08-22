#!/usr/bin/bash
# 🔗 https://github.com/klapptnot/dotf

# shellcheck disable=SC2120
function __mirkop_get_short_pwd {
  [ "${PWD}" == "${MIRKOP_LAST_PWD}" ] && printf '%b' "${MIRKOP_LAST_SPWD}" && return
  local short_pwd_s=""
  local old_pwd="${PWD}"
  if [[ "${PWD}" == "${HOME}"* ]]; then
    old_pwd="${PWD#*"${HOME}"}"
    short_pwd_s='~'
  fi
  for dir_item in ${old_pwd//\// }; do
    if [ "${dir_item}" == "${PWD##*/}" ]; then
      short_pwd_s+="/${dir_item}"
      break
    elif [ "${dir_item:0:1}" == "." ]; then
      short_pwd_s+="/${dir_item:0:2}"
      continue
    fi
    short_pwd_s+="/${dir_item:0:1}"
  done
  printf '%b' "${short_pwd_s}"
}

function __mirkop_cursor_position {
  # based on a script from http://invisible-island.net/xterm/xterm.faq.html
  exec < /dev/tty
  read -r oldstty < <(stty -g)
  stty raw -echo min 0
  printf '\033[6n' > /dev/tty
  IFS='[;' read -d R -rs _ row col
  stty "${oldstty}"
  echo -n "${row} ${col}"
}

function __mirkop_get_cwd_color {
  if [ "${MIRKOP_CONFIG[1]}" != 'true' ]; then
    printf '%s' "${MIRKOP_DIR_COLORS[5]}"
    return
  fi
  [ "${PWD}" == "${MIRKOP_LAST_PWD}" ] && printf '%s' "${MIRKOP_LAST_PWDC}" && return
  if command -v cksum &> /dev/null; then
    read -r s < <(pwd -P | cksum | cut -d' ' -f1 | printf '%-6x' "$(< /dev/stdin)" | tr ' ' '0' | head -c 6)
    local r=$((16#${s:0:2}))
    local g=$((16#${s:2:2}))
    local b=$((16#${s:4:2}))

    luminance=$((2126 * r + 7152 * g + 0722 * b))
    while ((luminance < 1200000)); do
      ((r = r < 255 ? r + 60 : 255))
      ((g = g < 255 ? g + 60 : 255))
      ((b = b < 255 ? b + 60 : 255))
      luminance=$((2126 * r + 7152 * g + 0722 * b))
    done
    ((r = r < 255 ? r : 255))
    ((g = g < 255 ? g : 255))
    ((b = b < 255 ? b : 255))

    printf '\\033[38;2;%d;%d;%dm' ${r} ${g} ${b}
  fi
}

function __mirkop_git_info {
  local git_branch=""

  if ! command -v git &> /dev/null || ! git rev-parse --is-inside-work-tree &> /dev/null; then
    printf '\n0\n'
    return
  fi

  read -r mod _ _ ins _ del _ < <(git diff --shortstat 2> /dev/null)
  read -r git_branch < <(git branch --show-current 2> /dev/null)
  mapfile -t untracked < <(git ls-files --other --exclude-standard 2> /dev/null)
  mapfile -t untracked_dirs < <(dirname -- "${untracked[@]}" 2> /dev/null | sort -u)

  # <files>@<branch> +<additions>/-<deletions> (● <untracked_files>@<untracked_folders>)
  printf '%b%d%b@%b%s%b %b+%d%b/%b-%d%b %b(● %d%b@%b%d%b)\033[0m\n' \
    "${MIRKOP_COLORS[9]}" "${mod}" "${MIRKOP_COLORS[10]}" \
    "${MIRKOP_COLORS[9]}" "${git_branch}" "${MIRKOP_COLORS[10]}" \
    "${MIRKOP_COLORS[7]}" "${ins}" "${MIRKOP_COLORS[10]}" \
    "${MIRKOP_COLORS[8]}" "${del}" "${MIRKOP_COLORS[10]}" \
    "${MIRKOP_COLORS[9]}" "${#untracked[@]}" "${MIRKOP_COLORS[10]}" \
    "${MIRKOP_COLORS[9]}" "${#untracked_dirs[@]}" "${MIRKOP_COLORS[10]}" 2> /dev/null

  : "${MIRKOP_COLORS[9]}${MIRKOP_COLORS[10]}${MIRKOP_COLORS[9]}"
  : "${_}${MIRKOP_COLORS[10]}${MIRKOP_COLORS[7]}${MIRKOP_COLORS[10]}"
  : "${_}${MIRKOP_COLORS[8]}${MIRKOP_COLORS[10]}${MIRKOP_COLORS[9]}"
  : "${_}${MIRKOP_COLORS[10]}${MIRKOP_COLORS[9]}${MIRKOP_COLORS[10]}\033[0m"
  : "${_@E}--"          # Somehow, it needs 2 characters to be right, so I added 2 dashes
  printf '%d\n' "${#_}" # Return the length of the color escape sequences
}

function __mirkop_generate_prompt_left {
  local -a prompt_parts=()

  read -r pwd_color < <(__mirkop_get_cwd_color)
  read -r short_cwd < <(__mirkop_get_short_pwd)

  prompt_parts+=(
    "\[${MIRKOP_COLORS[0]}\]${MIRKOP_STRINGS[0]}\[${MIRKOP_COLORS[3]}\]" # User
    "\[${MIRKOP_COLORS[1]}\]${MIRKOP_STRINGS[1]}\[${MIRKOP_COLORS[3]}\]" # From
    "\[${MIRKOP_COLORS[2]}\]${MIRKOP_STRINGS[2]}\[${MIRKOP_COLORS[3]}\]" # Host
    ":\[${pwd_color}\]${short_cwd}\[${MIRKOP_COLORS[3]}\]"               # CWD
    "${MIRKOP_STRINGS[3]} "                                              # Status and delim
  )
  printf -v prompt_string '%s' "${prompt_parts[@]}"

  PS1="${prompt_string}\[\033[0m\]"
}

function __mirkop_print_prompt_right {
  local -a rprompt_parts=()
  local comp=0

  {
    read -r git_info
    read -r color_length
  } < <(__mirkop_git_info)

  ((comp = comp + color_length))
  rprompt_parts+=("${git_info} ")

  jobs &> /dev/null # Prevent from printing finished jobs after command
  read -r num_jobs < <(jobs -r | wc -l)
  if ((num_jobs > 0)); then
    rprompt_parts+=("${MIRKOP_COLORS[6]}${num_jobs}  \033[0m ")
    : "${MIRKOP_COLORS[6]}\033[0m--"
    : "${_@E}"
    ((comp = comp + ${#_}))
  fi

  if ((${1} != 0)); then
    rprompt_parts+=("${MIRKOP_COLORS[4]}[${1}]\033[0m ")
    : "${MIRKOP_COLORS[4]}\033[0m"
    : "${_@E}"
    ((comp = comp + ${#_}))
  fi

  IFS=$'\n\t' read -r TIME_S < <(date "+${MIRKOP_CONFIG[2]}") && rprompt_parts+=("${TIME_S}")

  # Compensate the length of the right prompt
  # by adding the color escape sequences offset
  ((comp = COLUMNS + comp))

  printf -v rprompt_string "%b" "${rprompt_parts[@]}"
  printf "%${comp}s\x1b[0G" "${rprompt_string}"
}

function __mirkop_transient_prompt_left {
  read -r pwd_color < <(__mirkop_get_cwd_color)
  read -r short_cwd < <(__mirkop_get_short_pwd)

  printf '%b%s\x1b[0m:%s \x1b[38;5;14m%s\x1b[0m' "${pwd_color}" "${short_cwd}" "${MIRKOP_STRINGS[3]}" "${1}"
}

function __mirkop_transient_prompt_right {
  IFS=$'\n\t' read -r TIME_S < <(date "+${MIRKOP_CONFIG[2]}") && rprompt_parts+=("${TIME_S}")

  printf "%*s\x1b[0G" "${COLUMNS}" "${TIME_S}"
}

function __mirkop_generate_prompt {
  local last_exit_code="${?}"

  read -r row col < <(__mirkop_cursor_position 2> /dev/null)

  # If the last command prints data with no trailing linefeed
  # add an indicator, and a linefeed
  ((col > 1)) && printf "\x1b[38;5;242m⏎\x1b[0m\n" && ((row++))

  __mirkop_generate_prompt_left
  __mirkop_print_prompt_right "${last_exit_code}"
  MIRKOP_TRANSIENT_ADDED=0
  MIRKOP_LAST_POSITION="${row} ${col}"
}

function __mirkop_transient_prompt {
  ((MIRKOP_TRANSIENT_ADDED)) && return
  [[ "${MIRKOP_CONFIG[0]}" != 'true' ]] && return
  MIRKOP_TRANSIENT_ADDED=1

  # Overwrite the prompt cursor position, so it doesn't
  # randomly move around after `clear` command is issued
  [ "${LAST_COMMAND_ITER[0]%\ *}" == 'clear' ] && {
    MIRKOP_LAST_POSITION='1 1'
    MIRKOP_TRANSIENT_ADDED=0
    LAST_COMMAND_ITER=("${LAST_COMMAND_ITER[@]:1}")
  }

  # If the prompt was printed in the last row
  # of the terminal, set the position to the row above
  # so that the transient prompt doesn't get overwritten
  [ "${MIRKOP_LAST_POSITION}" == "${LINES} 1" ] && MIRKOP_LAST_POSITION="$((LINES - 1)) 1"

  local cmd_line_string=""
  local oIFS="${IFS}"
  ((MIRKOP_MAYBE_PIPE - 1)) && IFS='|' || IFS=';'
  cmd_line_string="${LAST_COMMAND_ITER[*]}"
  IFS="${oIFS}"

  LAST_COMMAND_ITER=()
  # shellcheck disable=SC2086
  printf '\x1b7\x1b[%d;%dH\x1b[0G\x1b[0K' ${MIRKOP_LAST_POSITION} 2> /dev/null
  __mirkop_transient_prompt_right
  __mirkop_transient_prompt_left "${cmd_line_string}"
  printf '\x1b8\x1b[0G'
}

function __mirkop_set_title {
  [ "${MIRKOP_CONFIG[3]}" != 'true' ] && return
  printf '\x1b]0;%s\x07' "${MIRKOP_SET_TITLE}"
}

function __mirkop_reset_title {
  read -r cwd < <(__mirkop_get_short_pwd)
  printf '\x1b]0;%s\x07' "${cwd}"
}

function __mirkop_update_term_size {
  read -r LINES COLUMNS < <(stty size)
}

function __mirkop_pre_command_hook {
  declare -g MIRKOP_MAYBE_PIPE="${#PIPESTATUS[@]}"
  [[ "${BASH_COMMAND}" != __* ]] && {
    LAST_COMMAND_ITER+=("${BASH_COMMAND}")
  }
  for cmd in "${MIRKOP_PRECMD_HOOKS[@]}"; do ${cmd}; done
}

function __mirkop_pre_prompt_hook {
  # run post-command hooks
  for cmd in "${MIRKOP_PREPROMPT_HOOKS[@]}"; do ${cmd}; done
}

#region Configuration
function __mirkop_load_prompt_config {
  function hex_to_shell {
    local s="${1:-}"

    if [[ ${#s} -ne 7 || ${s:0:1} != "#" ]]; then
      printf '\\033[0m'
      return
    fi

    local r=$((16#${s:1:2}))
    local g=$((16#${s:3:2}))
    local b=$((16#${s:5:2}))

    printf '\\033[38;2;%d;%d;%dm' ${r} ${g} ${b}
  }

  local from_key="base"
  [ -n "${SSH_TTY@A}" ] && from_key="sshd"

  local delim_key="else"
  ((EUID == 0)) && delim_key="root"

  source ~/.config/bash/yq.sh
  declare -A MIRKOP_YAML_CFG
  yq.sh MIRKOP_YAML_CFG ~/.config/mirkop.yaml
  unset -f yq.sh

  # MIRKOP_CONFIG
  declare -ga MIRKOP_CONFIG=(
    [0]="${MIRKOP_YAML_CFG[.transient]}" # Transient prompt
    [1]="${MIRKOP_YAML_CFG[.rdircolor]}" # Enable CWD color based on string
    [2]="${MIRKOP_YAML_CFG[.date_fmt]}"  # Date format
    [3]=true                             # Manage window title
  )

  # MIRKOP_STRINGS
  declare -ga MIRKOP_STRINGS=(
    [0]="${MIRKOP_YAML_CFG[.str.user]}"              # Username
    [1]="${MIRKOP_YAML_CFG[.str.from.${from_key}]}"  # From string
    [2]="${MIRKOP_YAML_CFG[.str.host]}"              # Hostname
    [3]="${MIRKOP_YAML_CFG[.str.char.${delim_key}]}" # Delimiter
  )

  # MIRKOP_COLORS
  read -r c_user < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.user.fg]}")
  read -r c_from < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.from.fg]}")
  read -r c_host < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.host.fg]}")
  read -r c_norm < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.normal.fg]}")
  read -r c_err < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.error.fg]}")
  read -r c_dir < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.dir.fg]}")
  read -r c_jobs < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.jobs.fg]}")
  read -r git_ins < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.git.i.fg]}")
  read -r git_del < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.git.d.fg]}")
  read -r git_any < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.git.a.fg]}")
  read -r git_sep < <(hex_to_shell "${MIRKOP_YAML_CFG[.color.git.s.fg]}")

  declare -ga MIRKOP_COLORS=(
    [0]="${c_user}"   # User color
    [1]="${c_from}"   # From color
    [2]="${c_host}"   # Host color
    [3]="${c_norm}"   # Normal color
    [4]="${c_err}"    # Error color
    [5]="${c_dir}"    # Directory color
    [6]="${c_jobs}"   # Jobs color
    [7]="${git_ins}"  # Git insertions color
    [8]="${git_del}"  # Git deletions color
    [9]="${git_any}"  # Git any changes color
    [10]="${git_sep}" # Git separator color
  )
  unset -f hex_to_shell
  return 0
}
#endregion

function __mirkop_main {
  if __mirkop_load_prompt_config; then
    declare -g MIRKOP_LAST_POSITION='0 0'
    declare -g MIRKOP_SET_TITLE=""
    declare -g MIRKOP_LAST_PWD=""
    declare -g MIRKOP_LAST_SPWD=""
    declare -g MIRKOP_LAST_PWDC=""
    declare -g MIRKOP_TRANSIENT_ADDED=0
    declare -ga LAST_COMMAND_ITER=()

    declare -ga MIRKOP_PRECMD_HOOKS=(
      '__mirkop_transient_prompt'
    )
    # BASH_COMMAND is set while and after command ran
    declare -ga MIRKOP_PREPROMPT_HOOKS=(
      '__mirkop_set_title'
      '__mirkop_update_term_size'
      '__mirkop_generate_prompt'
      '__mirkop_reset_title'
    )

    PROMPT_COMMAND='__mirkop_pre_prompt_hook'
    __mirkop_pre_prompt_hook
    trap -- '__mirkop_pre_command_hook' DEBUG
  fi
}

PROMPT_COMMAND='__mirkop_main'
