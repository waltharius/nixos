# new-host - register a new machine in the fleet (refactor stage 2, part A).
#
# Run from the repository root on the admin workstation:
#   nix run .#new-host
#
# Asks for the host's data (gum), then writes:
#   hosts/machines/<host>.nix                  inventory entry
#   hosts/<class dir>/<host>/                  host files from hosts/templates/
#   secrets/hosts/<host>/ssh_host_ed25519_key  new SSH host key, encrypted
#                                              for the admin keys only
# derives the host's age key from the SSH host key, regenerates .sops.yaml
# (nix run .#sops-config re-encrypts every secret the host uses) and
# evaluates the new host. Nothing is committed: review, then commit.
#
# Installing the machine (part B, nixos-anywhere) is a separate step.
# Details: docs/NEW-HOST.md.

die() {
  gum style --foreground 1 "new-host: $*" >&2
  exit 1
}

info() {
  gum style --foreground 4 "$*"
}

# Escape a value for a Nix double-quoted string.
nix_string() {
  local s=$1
  s=${s//\\/\\\\}
  s=${s//\"/\\\"}
  s=${s//\$\{/\\\$\{}
  printf '"%s"' "$s"
}

# Nix list of strings from the arguments.
nix_list() {
  local out="[" item
  for item in "$@"; do
    out+="$(nix_string "$item") "
  done
  printf '%s' "${out% }]"
}

# Copy a template, replacing the @NAME@ placeholders.
render() {
  local src=$1 dst=$2 content
  content=$(<"$src")
  content=${content//@HOST@/$name}
  content=${content//@DESCRIPTION@/$description}
  content=${content//@SYSTEM@/$system}
  content=${content//@STATE_VERSION@/$state_version}
  content=${content//@DISK@/$disk}
  content=${content//@EXTRA_IMPORTS@/$extra_imports}
  printf '%s\n' "$content" >"$dst"
}

# --- preconditions --------------------------------------------------------

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "run it inside the nixos repository"
cd "$root"
[[ -f flake.nix && -d hosts/machines && -d hosts/templates ]] || die "run it inside the nixos repository"

# The cleanup on failure restores .sops.yaml and secrets/ from git, so they
# must not hold uncommitted work.
git diff --quiet HEAD -- .sops.yaml secrets ||
  die ".sops.yaml or secrets/ has uncommitted changes; commit or stash them first"

admin_key_file=${SOPS_AGE_KEY_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/sops/age/keys.txt}
[[ -r $admin_key_file ]] || die "admin age key not found ($admin_key_file); run it on the admin workstation"

info "Reading the inventory..."
inventory=$(nix eval --json .#inventory) || die "the inventory does not evaluate; fix it first"
state_version=$(nix eval --raw --inputs-from . nixpkgs#lib.trivial.release)

taken_names=$(jq -r '(.machines | keys[]), (.devices | keys[]),
  (.machines[] | .ssh.aliases // {} | keys[]), (.devices[] | .ssh // {} | keys[])' <<<"$inventory")
prefix=$(jq -r '.network.lan.prefix' <<<"$inventory")
pool_first=$(jq -r '.network.lan.dhcpPool.first' <<<"$inventory")
pool_last=$(jq -r '.network.lan.dhcpPool.last' <<<"$inventory")
used_ips=$(jq -r '(.machines[], .devices[]) | .lan.ip // empty' <<<"$inventory")

# --- questions --------------------------------------------------------------

name=$(gum input --header "Host name" --placeholder "e.g. baal")
[[ $name =~ ^[a-z][a-z0-9-]*$ ]] || die "host name must match [a-z][a-z0-9-]*"
grep -qxF "$name" <<<"$taken_names" && die "$name is already a machine, device or SSH alias"

class=$(gum choose --header "Class (lib/classes.nix)" workstation server virtual)
case $class in
  workstation) host_dir=hosts/workstations/$name default_tags="workstation,laptop" default_user=marcin ;;
  server) host_dir=hosts/physical/$name default_tags="server,baremetal" default_user=nixadm ;;
  virtual) host_dir=hosts/virtual/$name default_tags="lxc" default_user=nixadm ;;
esac
[[ -e $host_dir ]] && die "$host_dir already exists"

# Only x86_64 for now: aarch64 hosts need meta.nodeNixpkgs in the hive.
system=x86_64-linux

description=$(gum input --header "Description" --placeholder "e.g. Dell Wyse 5470 - writing laptop")
tags_input=$(gum input --header "Colmena tags, comma separated" --value "$default_tags")
IFS=',' read -r -a tags <<<"${tags_input// /}"

# First free address outside the DHCP pool (not .1, the router).
suggest_ip() {
  local i
  for ((i = 2; i <= 254; i++)); do
    ((i >= pool_first && i <= pool_last)) && continue
    grep -qxF "$prefix.$i" <<<"$used_ips" || {
      echo "$prefix.$i"
      return
    }
  done
}

ip=""
interface=""
if [[ $class != workstation ]] || gum confirm --default=false "Static address on the home Wi-Fi (lan.ip)? Without it the workstation uses DHCP at home."; then
  ip=$(gum input --header "LAN address (outside $prefix.$pool_first-$pool_last)" --value "$(suggest_ip)")
  grep -qxF "$ip" <<<"$used_ips" && die "$ip is already used"
fi
if [[ $class == server ]]; then
  interface=$(gum input --header "Network interface for the static address (check after the hardware scan)" --value "enp1s0")
fi

mapfile -t accounts < <(find users -mindepth 1 -maxdepth 1 -type d -printf '%f\n' | sort)
mapfile -t users < <(gum choose --no-limit --header "Accounts on $name" --selected "$default_user" "${accounts[@]}")
((${#users[@]} > 0)) || die "a host needs at least one account"
if [[ $class != workstation ]] && ! printf '%s\n' "${users[@]}" | grep -qxF nixadm; then
  die "servers and virtual machines need the nixadm account"
fi

mapfile -t all_groups < <(nix eval --json --file modules/groups/default.nix --apply builtins.attrNames | jq -r '.[]')
declare -A user_groups
for user in "${users[@]}"; do
  user_groups[$user]=$(gum choose --no-limit --header "Program groups of $user on $name" --selected cli "${all_groups[@]}" | tr '\n' ' ')
done

layout=""
disk=""
extra_imports=""
if [[ $class != virtual ]]; then
  mapfile -t layouts < <(find hosts/templates/disko -name '*.nix' -printf '%f\n' | sed 's/\.nix$//' | sort)
  layout=$(gum choose --header "Disk layout (hosts/templates/disko/)" "${layouts[@]}")
  if [[ $layout == *-writing ]]; then
    [[ $class == workstation ]] || die "the $layout layout is for workstations"
    printf '%s\n' "${users[@]}" | grep -qxF marcin || die "the $layout layout holds marcin's writing subvolumes; marcin is not on $name"
    extra_imports="./writing.nix"
  fi
  disk=$(gum input --header "Install disk (prefer /dev/disk/by-id/...; can be changed before installing)" --value "/dev/sda")
fi

# --- summary ----------------------------------------------------------------
# Nothing has been written up to here: interrupting is always safe.

{
  echo "Host:        $name ($class, $system)"
  echo "Description: $description"
  echo "Tags:        ${tags[*]}"
  echo "LAN:         ${ip:-none}${interface:+ on $interface}"
  for user in "${users[@]}"; do
    echo "User:        $user - ${user_groups[$user]}"
  done
  [[ -n $layout ]] && echo "Disk:        $layout on $disk"
  echo "Files:       hosts/machines/$name.nix, $host_dir/, secrets/hosts/$name/"
} | gum style --border rounded --padding "0 1"
gum confirm "Create $name?" || exit 0

# --- files ------------------------------------------------------------------

created=()
cleanup_on_error() {
  gum style --foreground 1 "new-host: failed, removing the files it created"
  git restore --staged -- "${created[@]}" .sops.yaml secrets 2>/dev/null || true
  rm -rf -- "${created[@]}"
  git checkout -- .sops.yaml secrets 2>/dev/null || true
}
trap cleanup_on_error ERR

tmp=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/new-host.XXXXXX")
trap 'rm -rf "$tmp"' EXIT

info "Generating the SSH host key..."
ssh-keygen -q -t ed25519 -N "" -C "root@$name" -f "$tmp/ssh_host_ed25519_key"
host_key=$(cut -d' ' -f1,2 "$tmp/ssh_host_ed25519_key.pub")
age_key=$(ssh-to-age <"$tmp/ssh_host_ed25519_key.pub")

# Encrypted for the admin keys only (catch-all rule of .sops.yaml).
mkdir -p "secrets/hosts/$name"
created+=("secrets/hosts/$name")
# Encrypt into the temporary directory first: --filename-override only
# selects the .sops.yaml rule, but writing straight to that path looks like
# reading and writing one file in a pipeline (shellcheck SC2094).
sops encrypt --filename-override "secrets/hosts/$name/ssh_host_ed25519_key" \
  --input-type binary --output-type binary \
  "$tmp/ssh_host_ed25519_key" >"$tmp/ssh_host_ed25519_key.sops"
install -m 0644 "$tmp/ssh_host_ed25519_key.sops" "secrets/hosts/$name/ssh_host_ed25519_key"

info "Writing hosts/machines/$name.nix and $host_dir/..."
machine_file=hosts/machines/$name.nix
created+=("$machine_file")
{
  echo "# $machine_file - fields are described in hosts/README.md"
  echo "# Registered with \`nix run .#new-host\` on $(date +%F)."
  echo "{"
  echo "  class = \"$class\";"
  echo "  system = \"$system\";"
  echo "  description = $(nix_string "$description");"
  echo "  tags = $(nix_list "${tags[@]}");"
  if [[ -n $ip && -n $interface ]]; then
    echo "  lan = {"
    echo "    ip = \"$ip\";"
    echo "    interface = $(nix_string "$interface");"
    echo "  };"
  elif [[ -n $ip ]]; then
    echo "  lan.ip = \"$ip\";"
  fi
  echo "  users = {"
  for user in "${users[@]}"; do
    read -r -a groups <<<"${user_groups[$user]}"
    echo "    $user.groups = $(nix_list "${groups[@]}");"
  done
  echo "  };"
  echo ""
  echo "  # Age key derived from the SSH host key; its private part is stored"
  echo "  # in secrets/hosts/$name/ssh_host_ed25519_key (admin keys only)."
  echo "  sops = {"
  echo "    ageKey = \"$age_key\";"
  echo "    keySource = \"ssh-host-key\";"
  echo "  };"
  echo ""
  echo "  ssh.hostKey = \"$host_key\";"
  echo "}"
} >"$machine_file"

mkdir -p "$host_dir"
created+=("$host_dir")
for template in "hosts/templates/$class"/*.nix; do
  render "$template" "$host_dir/$(basename "$template")"
done
if [[ -n $layout ]]; then
  render "hosts/templates/disko/$layout.nix" "$host_dir/disko.nix"
fi
if [[ -n $extra_imports ]]; then
  render hosts/templates/writing.nix "$host_dir/writing.nix"
fi
# Templates leave an empty line where @EXTRA_IMPORTS@ was unused.
nix fmt -- "$machine_file" "$host_dir" >/dev/null

# The flake only sees files known to git.
git add -- "${created[@]}"

info "Regenerating .sops.yaml and re-encrypting the secrets $name uses..."
nix run .#sops-config
git add -- .sops.yaml secrets

info "Evaluating $name..."
drv=$(nix eval --raw ".#nixosConfigurations.$name.config.system.build.toplevel.drvPath")
trap - ERR

gum style --foreground 2 "$name registered: $drv"
cat <<EOF

Next:
  1. Review:  git diff --cached
  2. Check:   nix flake check
  3. Commit:  git commit -m 'feat(hosts): add $name ($class)'
  4. Install: nix run .#install-host -- $name root@<installer address>
     (docs/NEW-HOST.md). It replaces the placeholder
     $host_dir/hardware-configuration.nix. Do not deploy before.
EOF
