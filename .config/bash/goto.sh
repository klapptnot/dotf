#!/usr/bin/bash
# 🔗 https://github.com/klapptnot/dotf

# Check if this script is being executed as the main script
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  # Break execution
  printf "[\x1b[38;05;160m*\x1b[00m] This script is not made to run as a normal script\n"
  exit 1
fi

# Small utility to go to folders by alias
function goto {
  if [ -z "${1}" ]; then
    builtin cd "${HOME}" &> /dev/null || return
    return
  fi
  local print_path=false
  if [[ "${1}" =~ ^-p|--print$ ]]; then
    print_path=true
    shift 1
  elif [[ "${1}" =~ ^-h|--help$ ]]; then
    local help=(
      '\x1b[38;5;87mgoto\x1b[0m - Alias based fast cd (change dir)'
      'Usage: goto <path|alias> [...MODIFIERS]'
      '       goto -h|--help'
      '       goto -l|--list'
      'Example'
      '  # go to folder with alias "nf"'
      '  goto nf'
      '  # format "of" alias with "images"'
      '  goto of images'
      '  # go to home folder'
      '  goto'
    )
    printf '%b\n' "${help[@]}"
    return
  elif [[ "${1}" =~ ^-l|--list$ ]]; then
    if ! [ -f ~/.config/dotf/goto.idx ]; then
      printf '\x1b[38;5;85mIndex file not found, printing default aliases\x1b[0m\n'
      default_aliases=(
        '.c   &!HOME;/.config'
        'bin  /usr/bin'
        'lib  /usr/lib'
        'etc  /usr/etc'
        'dp   &!HOME;/Desktop'
        'nc   &*.c;/nvim'
      )
      # shellcheck disable=SC2128
      printf '%s\n' "${default_aliases[@]}"
      return
    fi
    printf '\x1b[38;5;85mPrinting aliases\x1b[0m\n%s\n' "$(< ~/.config/dotf/goto.idx)"
    return
  fi

  if [ -f ~/.config/dotf/goto.idx ]; then
    # shellcheck disable=SC2178
    declare -r PATH_INDEX_CONTENT="$(< ~/.config/dotf/goto.idx)"
  else
    # Set a default config, but give a warning
    default_aliases=(
      '.c   &!HOME;/.config'
      'bin  /usr/bin'
      'lib  /usr/lib'
      'etc  /usr/etc'
      'dp   &!HOME;/Desktop'
      'nc   &*.c;/nvim'
    )
    # shellcheck disable=SC2178
    printf -v PATH_INDEX_CONTENT '%s\n' "${default_aliases[@]}"
    declare -r PATH_INDEX_CONTENT="${PATH_INDEX_CONTENT}"
    printf '\x1b[38;5;191mIndex file no found, default aliases is set\x1b[0m\n'
  fi

  # shellcheck disable=SC2128
  local path_alias
  mapfile -t path_alias < <(awk '{ print $1 }' <<< "${PATH_INDEX_CONTENT}")

  declare -A ALIAS_FORMAT
  while read -r format; do
    ALIAS_FORMAT["${path_alias[0]}"]="${format}"
    path_alias=("${path_alias[@]:1}")
  done < <(awk '{ print $2 }' <<< "${PATH_INDEX_CONTENT}")
  unset path_alias

  local modifiers=("${@:2}")
  local path="${ALIAS_FORMAT[${1}]}"

  if [ -z "${path}" ]; then
    printf '\x1b[38;5;9mAlias "%s" not found\x1b[0m\n' "${1}"
    return 2
  fi
  # While replacing, do not allow & to reference the matched string
  local shopt_restore=false
  if shopt -q patsub_replacement; then
    shopt -u patsub_replacement
    shopt_restore=true
  fi
  while [[ ${path} =~ \&(\*|!|%)([^\;\s]*)\; ]]; do
    case "${BASH_REMATCH[1]}" in
      '*')
        if [ -z "${ALIAS_FORMAT[${BASH_REMATCH[2]}]}" ]; then
          printf '\x1b[38;5;9mAlias "%s" not found\x1b[0m\n' "${BASH_REMATCH[2]}"
          return 2
        fi
        path="${path//${BASH_REMATCH[0]}/${ALIAS_FORMAT["${BASH_REMATCH[2]}"]}\/}"
        ;;
      '!')
        if [ -z "${BASH_REMATCH[2]}" ]; then
          printf '\x1b[38;5;9mEnvironment variable "%s" inaccessible\x1b[0m\n' "${BASH_REMATCH[2]}"
          return 3
        fi
        path="${path//${BASH_REMATCH[0]}/${!BASH_REMATCH[2]}\/}"
        ;;
      '%')
        if [ -z "${modifiers[(${BASH_REMATCH[2]} - 1)]}" ]; then
          # shellcheck disable=SC2004
          printf '\x1b[38;5;9mModifiers number "%s" not found\x1b[0m\n' "$((${BASH_REMATCH[2]} - 1))"
          return 4
        fi
        path="${path//${BASH_REMATCH[0]}/${modifiers[(${BASH_REMATCH[2]} - 1)]}\/}"
        # modifiers=(
        #   "${modifiers[@]:0:${BASH_REMATCH[2]}-1}"
        #   "${modifiers[@]:${BASH_REMATCH[2]}}"
        # )
        ;;
    esac
  done
  if ${shopt_restore}; then
    shopt -s patsub_replacement
  fi
  for ((i = 0; i < ${#modifiers[@]}; i++)); do
    path="${path}/${modifiers[i]}"
  done
  read -r path < <(realpath "${path}") || path="${path//\/\//\/}"
  if ! [ -d "${path}" ]; then
    printf '\x1b[38;5;9mFolder "%s" does not exist or is not accessible\x1b[0m\n' "${path}"
    return 7
  fi
  if ${print_path}; then
    printf '%s' "${path}"
  else
    builtin cd "${path}" &> /dev/null || return
  fi
}
