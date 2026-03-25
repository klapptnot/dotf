#!/usr/bin/bash

# Simple YAML value reader
# NO SUPPORT FOR SETS, TAGS, SCALARS, etc.
# NO SUPPORT FOR NESTED ARRAYS
# ONLY KEY-VALUE, strings and integers, nested and plain arrays
#
# Usage: yq.sh <file> <section1> [section2 ...]
#   Each section name must match a top-level YAML key.
#   Each section name must correspond to a declared associative array.
#   A parallel indexed array pre_config_<section> is populated in insertion order.
#
# Example:
#   declare -A global system secure
#   yq.sh ~/.config/settings.yaml global system secure
#   for key in "${pre_config_global[@]}"; do
#     printf '%s = %s\n' "${key}" "${global[${key}]}"
#   done

function yq.sh {
  local file="${1}"
  declare -n the_root_ref_tm="${2}"
  shift 2

  [[ -z "${file}" || "${file}" == '-' ]] && file='/dev/stdin'

  local -a targets=("${@}")
  local -a lines=()
  mapfile -t lines < "${file}"

  # Build a set of target section names for O(1) lookup
  local -A target_set=()
  for t in "${targets[@]}"; do
    target_set["${t}"]=1
  done

  local -a fpa=()
  local -i last_ci=-1
  local -i ci=0
  local -i cai=-1
  local -i pa=0
  local k='' v='' npath='' last_index=''
  local pop_2=false
  local multiline=false
  local multiline_fold=false
  local multiline_strp=false
  local multiline_str=''
  local mmode='' smode='' discr='' multiline_npath='' multiline_nparn=''
  local -i indent=2
  local oifs="${IFS}"

  # Writes a value to the correct target array and its pre_config sidecar.
  # $1 = dot-path like global.font_size
  # $2 = value
  function __yq_store {
    local top_lvl_name="${1}"
    local subpath="${2}"
    local val="${3}"

    # If there's no sub-key (top-level scalar), subpath == top_lvl_name
    [[ -z "${subpath}" ]] && {
      the_root_ref_tm["${top_lvl_name}"]="${val}"
      return 0
    }

    [[ -z "${target_set[${top_lvl_name}]+x}" ]] && return 0

    local store_key="${subpath:-.}"

    local -n __yq_target="${top_lvl_name}"
    __yq_target["${store_key}"]="${val}"
  }

  for line in "${lines[@]}"; do
    case "${line}" in
      '#'* | '---') continue ;;
      '') "${multiline}" || continue ;;
    esac
    [[ "${line#*"${line%%[![:space:]]*}"}" == '#'* ]] && continue

    if "${multiline}"; then
      discr="${line::$((ci + indent))}"
      if [[ -n "${line}" && -z "${discr#*"${discr%%[![:space:]]*}"}" ]]; then
        if [[ -n "${multiline_str}" ]]; then
          "${multiline_fold}" && multiline_str+=' ' || multiline_str+=$'\n'
        fi
        multiline_str+="${line:$((ci + indent)):${#line}}"
        continue
      fi

      v="${multiline_str}"
      "${multiline_strp}" && v="${v%"${v##*[![:space:]$'\n']}"}"
      "${multiline_fold}" && v="${v%"${v##*[![:space:]$'\n']}"}"

      # npath was captured at multiline block start — use saved path
      __yq_store "${multiline_nparn}" "${multiline_npath}" "${v}"

      multiline_str=''
      multiline=false
      multiline_npath=''
      multiline_nparn=''
    fi

    IFS=':' read -r key val <<< "${line}"
    IFS="${oifs}"

    k="${key#"${key%%[![:space:]]*}"}"
    v="${val:1}"

    : "${key%%[![:space:]]*}"
    ci="${#_}"

    if [[ "${k}" == '- '* ]]; then
      if [[ -n "${v}" ]]; then
        # list of objects: - key: val
        ((ci = ci + indent))
        k="${k:${indent}}"
        pop_2=true
      else
        # plain array: - value
        v="${k:${indent}}"
        k=''
      fi

      if ((cai > -1)); then
        if "${pop_2}"; then
          last_index="${fpa[-1]}"
          fpa=("${fpa[@]:0:$((${#fpa[@]} - 2))}")
        else
          unset 'fpa[-1]'
        fi
      fi
      ((cai = cai + 1))
      fpa+=("${cai}")
      if [[ -n "${last_index}" ]]; then
        fpa+=("${last_index}")
        last_index=''
      fi
    elif [[ "${v}" == '|'* || "${v}" == '>'* ]]; then
      mmode="${v:0:1}"
      smode="${v:1:1}"
      multiline=true
      multiline_fold=false
      multiline_strp=false
      [[ "${mmode}" == '>' ]] && multiline_fold=true
      [[ "${smode}" == '-' ]] && multiline_strp=true
    fi

    if ((last_ci > ci)); then
      ((pa = ci / indent))
      last_ci=${ci}
      fpa=("${fpa[@]:0:${pa}}")
      [[ -n "${k}" ]] && fpa+=("${k}")
      cai=-1
      pop_2=false
    elif ((last_ci < ci)); then
      last_ci=${ci}
      [[ -n "${k}" ]] && fpa+=("${k}")
    else
      if [[ -n "${line}" ]]; then
        if ((cai < 0)) || "${pop_2}"; then
          (("${#fpa[@]}" > 0)) && unset 'fpa[-1]'
          [[ -n "${k}" ]] && fpa+=("${k}")
        fi
      fi
    fi

    "${multiline}" && {
      IFS=. multiline_npath="${fpa[*]:1}"
      IFS="${oifs}"
      multiline_nparn="${fpa[0]}"
      continue
    }

    case "${v}" in
      "'"*"'" | '"'*'"') v="${v:1:-1}" ;;
    esac

    if [[ -n "${v}" ]]; then
      IFS=. npath="${fpa[*]:1}"
      IFS="${oifs}"
      __yq_store "${fpa[0]}" "${npath}" "${v}"
    fi
  done

  # flush any trailing multiline block
  if [[ -n "${multiline_str}" ]]; then
    __yq_store "${multiline_nparn}" "${multiline_npath}" "${multiline_str}"
  fi

  unset -f __yq_store
  return 0
}
