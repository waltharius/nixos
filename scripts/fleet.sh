# fleet - one entry point for repository and fleet tasks (refactor stage 8,
# started in stage 5b; BACKLOG.md).
#
#   nix run .#fleet                  choose a task from a searchable list
#   nix run .#fleet -- <task> [...]  run a task directly, e.g.
#                                    nix run .#fleet -- monitoring apply --check
#   nix run .#fleet -- --help        list the tasks
#
# Run it from the repository on the admin workstation (azazel). A task that
# changes files validates them, stages them with `git add` and prints a
# ready-to-copy `git commit` command; it never commits.
#
# Adding a task: a function task_<words> and a line in TASKS below.

die() {
  gum style --foreground 1 "fleet: $*" >&2
  exit 1
}

info() {
  gum style --foreground 4 "$*"
}

# "<task>|<description>"; the task is two words, the function name joins
# them with "_".
TASKS=(
  "monitoring apply|Install or update monitoring agents (cAdvisor) on devices without NixOS (Ansible)"
  "host new|Register a new NixOS machine (nix run .#new-host)"
  "host install|Install a registered machine with nixos-anywhere (nix run .#install-host)"
  "secrets update|Regenerate .sops.yaml and re-encrypt every secret for its audience (nix run .#sops-config)"
)

usage() {
  printf 'Usage: nix run .#fleet [-- <task> [options]]\n\nTasks:\n'
  local t
  for t in "${TASKS[@]}"; do
    printf '  %-18s %s\n' "${t%%|*}" "${t#*|}"
  done
  printf '\nmonitoring apply options: --agent <name> --check | --apply --all | --limit <device> (repeatable)\n'
}

# Prints the chosen task ("<word> <word>"), nothing when cancelled.
pick_task() {
  local lines=() t choice
  for t in "${TASKS[@]}"; do
    lines+=("$(printf '%-18s %s' "${t%%|*}" "${t#*|}")")
  done
  choice=$(printf '%s\n' "${lines[@]}" | gum filter --header "Choose a task (type to search, Esc to quit)" --height 15) || return 0
  local first second
  read -r first second _ <<<"$choice"
  printf '%s %s\n' "$first" "$second"
}

# --- monitoring apply -----------------------------------------------------

# Monitoring agents installed with Ansible on devices without NixOS:
# "<agent>|<device field monitoring.X>|<playbook>|<metrics port>"
AGENTS=(
  "cadvisor|cadvisor|ansible/playbooks/cadvisor.yml|8080"
)

ensure_collections() {
  local dir=ansible/.collections sum stamp
  sum=$(sha256sum ansible/requirements.yml | cut -d' ' -f1)
  stamp="$dir/.requirements.sha256"
  if [[ -f $stamp && $(<"$stamp") == "$sum" ]]; then
    return 0
  fi
  info "Installing Ansible collections (ansible/requirements.yml)..."
  rm -rf "$dir"
  mkdir -p "$dir"
  ansible-galaxy collection install -r ansible/requirements.yml -p "$dir" ||
    die "installing the Ansible collections failed"
  printf '%s\n' "$sum" >"$stamp"
}

task_monitoring_apply() {
  local agent="" mode="" select_all=false limit=()
  while (($# > 0)); do
    case $1 in
      --agent)
        agent=${2:-}
        shift
        ;;
      --check) mode=check ;;
      --apply) mode=apply ;;
      --all) select_all=true ;;
      --limit)
        limit+=("${2:-}")
        shift
        ;;
      *) die "monitoring apply: unknown option $1 (see --help)" ;;
    esac
    shift
  done

  # Which agent.
  local names=() a
  for a in "${AGENTS[@]}"; do
    names+=("${a%%|*}")
  done
  if [[ -z $agent ]]; then
    if ((${#names[@]} == 1)); then
      agent=${names[0]}
    else
      agent=$(gum choose --header "Agent" "${names[@]}") || exit 0
    fi
  fi
  local entry="" field playbook port
  for a in "${AGENTS[@]}"; do
    [[ ${a%%|*} == "$agent" ]] && entry=$a
  done
  [[ -n $entry ]] || die "unknown agent $agent (known: ${names[*]})"
  IFS='|' read -r _ field playbook port <<<"$entry"

  # Devices that want it.
  info "Reading the inventory..."
  local inventory
  inventory=$(nix eval --json .#inventory) || die "the inventory does not evaluate; fix it first"
  local devices=()
  mapfile -t devices < <(jq -r --arg f "$field" \
    '.devices | to_entries[] | select(.value.monitoring[$f] == true) | .key' <<<"$inventory")
  ((${#devices[@]} > 0)) ||
    die "no device sets monitoring.$field = true; add it to hosts/devices/<name>.nix first"

  # Which of them.
  local selected=() d
  if ((${#limit[@]} > 0)); then
    for d in "${limit[@]}"; do
      printf '%s\n' "${devices[@]}" | grep -qx -- "$d" ||
        die "$d does not set monitoring.$field = true"
    done
    selected=("${limit[@]}")
  elif $select_all; then
    selected=("${devices[@]}")
  else
    mapfile -t selected < <(gum choose --no-limit \
      --header "Devices for $agent (space toggles, enter confirms)" \
      --selected "$(
        IFS=,
        printf '%s' "${devices[*]}"
      )" "${devices[@]}")
    ((${#selected[@]} > 0)) || exit 0
  fi

  # Check or apply.
  if [[ -z $mode ]]; then
    local choice
    choice=$(gum choose --header "Mode" \
      "check  - dry run: show what would change, change nothing" \
      "apply  - install or update") || exit 0
    mode=${choice%% *}
  fi

  # Before installing, so ansible-galaxy knows the target directory is a
  # configured collections path.
  export ANSIBLE_CONFIG="$PWD/ansible/ansible.cfg"
  export ANSIBLE_COLLECTIONS_PATH="$PWD/ansible/.collections"
  ensure_collections

  # Inventory for Ansible: the group named like the agent, one host per
  # device, named like its SSH alias so the generated ssh config supplies
  # address, user and key. Playbooks set `become: true` at play level (the
  # roles keep `become: false` for their downloads on this machine); root
  # logins become root with su, because Debian guests may have no sudo,
  # other users with sudo. ansible_become itself is not set here: as a
  # variable it would override the roles' `become: false`.
  # Global, not local: the EXIT trap runs after this function returns.
  fleet_tmp=$(mktemp -d)
  trap 'rm -rf "${fleet_tmp:-}"' EXIT
  local tmp=$fleet_tmp
  jq --arg group "$agent" --args '
    .devices as $devs
    | {all: {children: {($group): {hosts: (
        $ARGS.positional
        | map({key: ., value: (
            if ($devs[.].ssh[.].user // "") == "root"
            then {ansible_become_method: "su"}
            else {}
            end)})
        | from_entries)}}}}' "${selected[@]}" <<<"$inventory" >"$tmp/inventory.json"

  local args=(-i "$tmp/inventory.json" "$playbook" --diff)
  [[ $mode == check ]] && args+=(--check)

  info "ansible-playbook $playbook ($mode) on: ${selected[*]}"
  ansible-playbook "${args[@]}" || die "ansible-playbook failed"

  [[ $mode == apply ]] || return 0

  # Is the agent answering?
  local ip failed=0
  for d in "${selected[@]}"; do
    ip=$(jq -r --arg d "$d" '.devices[$d].lan.ip' <<<"$inventory")
    if curl -fsS -o /dev/null --max-time 10 "http://$ip:$port/metrics"; then
      info "$d: $agent answers on http://$ip:$port/metrics"
    else
      gum style --foreground 1 "$d: $agent does not answer on http://$ip:$port/metrics"
      failed=1
    fi
  done

  local server
  server=$(jq -r '.monitoring.server' <<<"$inventory")
  info "Prometheus scrapes devices with monitoring.$field = true once $server runs the current configuration (colmena apply --on $server)."
  return "$failed"
}

# --- dispatch -------------------------------------------------------------

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "run it inside the nixos repository"
cd "$root"
[[ -f flake.nix && -d hosts/machines ]] || die "run it inside the nixos repository"

case ${1:-} in
  -h | --help)
    usage
    exit 0
    ;;
esac

if (($# == 0)); then
  read -r -a words <<<"$(pick_task)"
  ((${#words[@]} > 0)) || exit 0
  set -- "${words[@]}"
fi

task="${1:-} ${2:-}"
shift $(($# < 2 ? $# : 2))

case $task in
  "monitoring apply") task_monitoring_apply "$@" ;;
  "host new") exec nix run .#new-host -- "$@" ;;
  "host install") exec nix run .#install-host -- "$@" ;;
  "secrets update") exec nix run .#sops-config -- "$@" ;;
  *)
    usage >&2
    exit 1
    ;;
esac
