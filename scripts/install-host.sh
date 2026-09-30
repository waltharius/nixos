# install-host - install a registered machine with nixos-anywhere
# (refactor stage 3, part B of `new-host`).
#
# Run from the repository root on the admin workstation:
#   nix run .#install-host -- <host> root@<address>
#
# The target must be booted into the NixOS installer (USB), be reachable
# over SSH as root, and the host must be registered with `nix run
# .#new-host` (docs/NEW-HOST.md). This script
#   - decrypts the stored SSH host key (secrets/hosts/<host>/) into a
#     temporary directory in $XDG_RUNTIME_DIR and hands it to the
#     installation, so the host keeps its identity and can decrypt its
#     secrets on the first boot;
#   - asks for the LUKS passphrase when disko.nix encrypts the disk and
#     passes it to the installer (/tmp/secret.key, used only while
#     formatting);
#   - runs nixos-anywhere, which partitions the disk with disko.nix,
#     replaces the placeholder hardware-configuration.nix with the result
#     of nixos-generate-config on the target, installs and reboots.
# Nothing is committed: review hardware-configuration.nix, then commit.

die() {
  gum style --foreground 1 "install-host: $*" >&2
  exit 1
}

info() {
  gum style --foreground 4 "$*"
}

(($# == 2)) || die "usage: nix run .#install-host -- <host> root@<address>"
host=$1
target=$2

root=$(git rev-parse --show-toplevel 2>/dev/null) || die "run it inside the nixos repository"
cd "$root"
[[ -f hosts/machines/$host.nix ]] || die "$host is not registered (hosts/machines/$host.nix); run nix run .#new-host first"

inventory=$(nix eval --json ".#inventory.machines.$host") || die "the inventory does not evaluate"
class=$(jq -r '.class' <<<"$inventory")
key_source=$(jq -r '.sops.keySource' <<<"$inventory")
host_key=$(jq -r '.ssh.hostKey // empty' <<<"$inventory")

case $class in
  workstation) host_dir=hosts/workstations/$host ;;
  server) host_dir=hosts/physical/$host ;;
  *) die "class $class is not installed with nixos-anywhere" ;;
esac
[[ -f $host_dir/disko.nix ]] || die "$host_dir/disko.nix is missing"

hardware=$host_dir/hardware-configuration.nix
if ! grep -q 'PLACEHOLDER written by' "$hardware"; then
  gum confirm --default=false "$hardware is not the placeholder: is this a reinstall? It will be overwritten." || exit 0
fi

tmp=$(mktemp -d "${XDG_RUNTIME_DIR:-/tmp}/install-host.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
args=()

# --- SSH host key -------------------------------------------------------------

key_file=secrets/hosts/$host/ssh_host_ed25519_key
if [[ -f $key_file ]]; then
  [[ -n $host_key ]] || die "$key_file exists but hosts/machines/$host.nix has no ssh.hostKey"
  info "Decrypting the SSH host key of $host..."
  install -d -m 0755 "$tmp/extra/etc/ssh"
  (umask 077 && sops -d --input-type binary --output-type binary "$key_file" >"$tmp/extra/etc/ssh/ssh_host_ed25519_key")
  printf '%s root@%s\n' "$host_key" "$host" >"$tmp/extra/etc/ssh/ssh_host_ed25519_key.pub"
  chmod 0644 "$tmp/extra/etc/ssh/ssh_host_ed25519_key.pub"
  args+=(--extra-files "$tmp/extra")
elif [[ $key_source == ssh-host-key ]]; then
  die "$host derives its age key from the SSH host key, but $key_file is missing"
fi

# --- LUKS passphrase ------------------------------------------------------------

if grep -q 'passwordFile = "/tmp/secret.key"' "$host_dir/disko.nix"; then
  pass1=$(gum input --password --header "LUKS passphrase for $host")
  pass2=$(gum input --password --header "LUKS passphrase again")
  [[ -n $pass1 && $pass1 == "$pass2" ]] || die "the passphrases are empty or differ"
  (umask 077 && printf '%s' "$pass1" >"$tmp/disk.key")
  unset pass1 pass2
  args+=(--disk-encryption-keys /tmp/secret.key "$tmp/disk.key")
fi

# --- install --------------------------------------------------------------------

disk=$(grep -m1 -o 'device = "[^"]*"' "$host_dir/disko.nix" | cut -d'"' -f2)
gum style --border rounded --padding "0 1" \
  "Host:    $host ($class)" \
  "Target:  $target" \
  "Disk:    $disk - EVERYTHING ON IT WILL BE ERASED" \
  "Writes:  $hardware"
gum confirm --default=false "Install $host on $target?" || exit 0

nixos-anywhere \
  --flake ".#$host" \
  --target-host "$target" \
  --generate-hardware-config nixos-generate-config "$hardware" \
  "${args[@]}"

git add -- "$hardware"
cat <<EOF

$host is installed and reboots now.
  1. Unlock the disk at the console, log in, check the system.
  2. Review:  git diff --cached $hardware
  3. Commit:  git commit -m 'feat(hosts): install $host, hardware configuration from nixos-generate-config'
EOF
