def --env get-env [name] { $env | get $name }
def --env set-env [name, value] { load-env { $name: $value } }
def --env unset-env [name] { hide-env $name }

let barg_allowed: list<string> = open ~/.config/.bargcomp.json
$env.config.completions.external = {
  enable: true
  max_results: $env.config.completions.external.max_results
  completer: { |spans: list<string>|
    # if the current command is an alias, get it's expansion
    let expanded_alias = (scope aliases | where name == $spans.0 | get --optional 0.expansion)

    # shadow
    let spans = (
      if $expanded_alias != null  {
        $spans | skip 1 | prepend ($expanded_alias | split row " " | take 1)
      } else {
        $spans
      }
    )
    let cmd_name: string = $spans.0

    let comps = if ($cmd_name in $barg_allowed) {
      (^$cmd_name @nucomp ...($spans))
    } else {
      # carapace is annoying when it gives no results
      # and you can't append a file path to the command line
      (
        CARAPACE_LENIENT=1 CARAPACE_MATCH=1
        CARAPACE_BRIDGES='clap,cobra,complete,inshellisense'
        carapace $cmd_name nushell ...$spans
      )
    }


    # So, fallback to nushell if its empty
    if $comps != '[]' {
      ($comps | from json)
    }

    # else {
    #   let files = (
    #     try { ls ($spans | last) | get name type }
    #     catch {
    #       try { ls | get name type } catch { [[],[]] }
    #     }
    #   )
    #   if ($files.0 | length) > 0 {
    #     $files.0 | enumerate | each {
    #       let index = $in.index
    #       {
    #         display: $in.item, # | str substring ..49 | str replace --regex '^(.{49}).$' "${1}..."
    #         value: $in.item,
    #         style: (
    #           $env.LS_COLORS
    #           | parse --regex '(?<ft>[^:]*)=(?<cl>[^:]*)'
    #           | find (
    #             $files.1
    #             | get $index
    #             | split row '.'
    #             | reverse
    #             | get 0?
    #           )
    #           | get 0?.cl
    #           | default 32
    #         )
    #       }
    #     }
    #   } else {
    #     []
    #   }
    # }
  }
}
