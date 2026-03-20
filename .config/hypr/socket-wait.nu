#!/usr/bin/nu

def die [msg: string] {
    print -e $msg
    exit 1
}

let max_iter = 15
let hypr_runtime_dir = $"($env.XDG_RUNTIME_DIR)/hypr/"

for _ in 1..$max_iter {
    if ($hypr_runtime_dir | path exists) { break }
    sleep 250ms
}

if not ($hypr_runtime_dir | path exists) {
    die "Max iterations reached waiting for hypr directory"
}

let instance_dirs: list<string> = (ls --full-paths $hypr_runtime_dir | where type == dir | get name)
let old_instances = ($instance_dirs | length)

mut hypr_instance_dir = ""
for _ in 1..$max_iter {
    let prob_instances: list<string> = (ls --full-paths $hypr_runtime_dir | where type == dir | get name)

    if ($prob_instances | length) > $old_instances {
        $hypr_instance_dir = $prob_instances | last
        break
    }

    sleep 100ms
}

if $hypr_instance_dir == "" { die $"Max iterations reached waiting for new instance directory" }

let hypr_instance_signature = ($hypr_instance_dir | path basename)
let socket_path = $hypr_instance_dir | path join ".socket.sock"

for _ in 1..$max_iter {
    if ($socket_path | path exists) {
        systemctl --user set-environment $"HYPRLAND_INSTANCE_SIGNATURE=($hypr_instance_signature)"
        exit 0
    }

    sleep 100ms
}

die $"Max iterations reached waiting for socket in ($hypr_instance_dir)"
