# 🔗 https://github.com/klapptnot/dotf

# Simple, nice and customizable shell prompt

def path-shorten []: string -> string {
  let path_parts = ($in | path split)

  $path_parts | drop 1 | each { |part|
    match $part {
      "" => $part,
      $s if ($s | str starts-with ".") => ($s | str substring 0..1),
      $s => ($s | str substring 0..0)
    }
  } | append ($path_parts | last) | path join
}

def get-path-fg-color []: string -> record<fg: string> {
  if $env.mirko.rdircolor != true or ((which cksum).command?.0? == null) {
    return $env.mirko.color.dir
  }

  let hex = (
    ($in | cksum | split row " ").0
    | awk '{printf "%x", $1}'
    | fill --width 6 --character 0
    | str substring ..5
  )

  return {
    fg: $"#($hex)"
  }
}

def git-status-info []: nothing -> record<f: int, i: int, d: int, u: int, U: int, b: string> {
  let changes = (git diff --shortstat | complete | get stdout | parse --regex '\s*(?<f>[0-9]+)[^0-9]*(?<i>[0-9]+)[^0-9]*(?<d>[0-9]+)')
  let untracked = (git ls-files --other --exclude-standard | lines)
  let u_folders = ($untracked | path dirname | uniq | length)


  # Create a record with the calculated values
  {
    f: ($changes | get f.0? | default 0 | into int),
    i: ($changes | get i.0? | default 0 | into int),
    d: ($changes | get d.0? | default 0 | into int),
    u: ($untracked | length),
    U: $u_folders,
    b: (git branch --show-current)
  }
}

def __left_prompt_command [--transient]: nothing -> string {
  let dir = match (do --ignore-errors { $env.PWD | path relative-to $nu.home-dir }) {
    null => $env.PWD
    '' => '~'
    $relative_pwd => ([~, $relative_pwd] | path join)
  }

  if $env.mirkov.ldir != $dir {
    $env.mirkov.ldir = $dir
    $env.mirkov.sdir = ($dir | path-shorten)
    $env.mirkov.cdir = ansi --escape ($dir | get-path-fg-color)
  }

  if $transient {
    return $"($env.mirkov.cdir)($env.mirkov.sdir)(ansi reset):"
  }

  [
    $env.mirkov.cuser,
    $env.mirko.str.user,
    $env.mirkov.cfrom,
    $env.mirko.str.from,
    $env.mirkov.chost,
    $env.mirko.str.host,
    ' ',
    $env.mirkov.cdir,
    $env.mirkov.sdir,
  ] | str join
}

def __right_prompt_command [--transient]: nothing -> string {
  mut parts = []

  if not $transient {
    if ($env.LAST_EXIT_CODE != 0) {
      $parts ++= [$env.mirkov.cerr, ($env.LAST_EXIT_CODE | into string), "? "]
    }

    if (git rev-parse --is-inside-work-tree | complete).exit_code == 0 {
      let col = $env.mirko.color.git
      let data = (git-status-info)

      if $env.mirko.collapse > (term size).columns {
        $parts ++= [$col.a, $data.f, $col.s, "@", $col.a, $data.b, $col.s, $env.mirkov.creset, " "]
      } else {
        $parts ++= [
          $col.a, $data.f, $col.s, "@", $col.a, $data.b, $col.s
          " ", $col.i, "+", $data.i, $col.s, "/", $col.d, "-", $data.d, $col.a,
          " (● ", $data.u, $col.s, "@", $col.a, $data.U, ")", $env.mirkov.creset, " "
        ]
      }
    }

    let duration = history | last | get --optional duration
    if $duration != null {
      $duration | into string | str replace --regex --all '([0-9]+)' $"($env.mirkov.cduration)${1}($env.mirkov.creset)"
    }
  }

  $parts ++= [$env.mirkov.ctime, (date now | format date '%X' |
    | str replace --regex --all "([/:])" $"($env.mirkov.ctime_sep)${1}($env.mirkov.ctime)"
    | str replace --regex --all "([AP]M)" $"($env.mirkov.ctime_period)${1}($env.mirkov.creset)"
  )]

  $parts | str join
}

# Initialize config file
let mirko_path = ([$env.HOME, ".config", "mirkop.yaml"] | path join)

if not ($mirko_path | path exists) {
  open ([$nu.default-config-dir, "mirkop.yaml"] | path join) |
    update str.user $env.USER |
    update str.host (uname).nodename |
    to yaml | save -f $mirko_path
}

$env.mirko = ($mirko_path | open)

# Set up git colors
$env.mirko.color.git =   {
  i: (ansi $env.mirko.color.git.i) # Insertion
  d: (ansi $env.mirko.color.git.d) # Deletion
  a: (ansi $env.mirko.color.git.a) # Anything
  s: (ansi $env.mirko.color.git.s) # Separators
}

# Distinguish between a SSH connection and a local shell session
$env.mirko.str.from = (if ($env.SSH_TTY? | default nothing) == nothing { $env.mirko.str.from.base } else { $env.mirko.str.from.sshd })

# PWD shortening variables, last short path and short
$env.mirkov = {
  # last, short version, current
  ldir: "",
  sdir: "",
  cdir: "",
  cuser: (ansi --escape $env.mirko.color.user),
  cfrom: (ansi --escape $env.mirko.color.from),
  chost: (ansi --escape $env.mirko.color.host),
  cnorm: (ansi --escape $env.mirko.color.normal)

  creset:       (ansi reset),
  ctime:        (ansi grey74),
  ctime_sep:    (ansi grey85),
  ctime_period: (ansi white_underline),
  cduration:    (ansi plum1),
  cerr:         (ansi rb)
}

# PROMPT_INDICATOR character for admin|sudo and normal user
$env.mirko.str.char = (if (is-admin) { $env.mirko.str.char.root } else { $env.mirko.str.char.else })
$env.mirko.str.char = $"(ansi --escape $env.mirko.color.normal)($env.mirko.str.char)(ansi reset) "

$env.PROMPT_COMMAND = {|| __left_prompt_command }
$env.PROMPT_COMMAND_RIGHT = {|| __right_prompt_command }
$env.PROMPT_INDICATOR = {|| $env.mirko.str.char }

if $env.mirko.transient == true {
  $env.TRANSIENT_PROMPT_COMMAND = {|| __left_prompt_command --transient }
  $env.TRANSIENT_PROMPT_COMMAND_RIGHT = {|| __right_prompt_command --transient }
  $env.TRANSIENT_PROMPT_INDICATOR = {|| $env.mirko.str.char }
}
