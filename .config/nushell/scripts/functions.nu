def __unfreeze_last_app [] {
  let frozen  = job list | where type == frozen | last

  if $frozen != null {
    job unfreeze $frozen.id
  }
}

def __open_file_nvim [] {
  let f = (
    fzf
    --prompt 'File: '
    --preview-window '65%' --preview-label 'Preview'
    --preview 'bat {}' | complete
  )
  if $f.stdout != '' { nvim ($f.stdout | str trim) }
}
