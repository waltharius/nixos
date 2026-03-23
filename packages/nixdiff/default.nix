# packages/nixdiff/default.nix
#
# nixdiff — compare two NixOS generations to see what changed
#
# WHY THIS EXISTS
# ───────────────
# Every time you run `nixos-rebuild switch`, NixOS creates a new *generation*:
# a numbered snapshot of your entire system closure stored as a symlink under
# /nix/var/nix/profiles/system-<N>-link  →  /nix/store/<hash>-nixos-system-...
#
# The actual comparison is done by `nix store diff-closures`, which walks the
# full dependency graph (the "closure") of each generation and reports:
#   ∅ → 1.2.3    = newly installed
#   1.2.3 → ∅    = removed
#   1.2.3 → 2.0  = updated
#   ±X KiB       = size change without a version bump
#
# If `nvd` is available it is preferred because it produces colour-coded,
# human-friendly output with explicit ADDED / REMOVED / UPGRADED sections.
# Fallback is the built-in `nix store diff-closures`.
#
# USAGE
# ─────
#   nixdiff              # auto: compare the two most recent generations
#   nixdiff 79           # find what came before 79, compare that pair
#   nixdiff 78 79        # explicit FROM → TO
#   nixdiff 75 79        # compare any two arbitrary generation numbers
#
# HOW GENERATION RESOLUTION WORKS
# ────────────────────────────────
# Generations are not guaranteed to be consecutive — you may have deleted old
# ones with `nix-collect-garbage`. So we never assume gen N-1 exists; instead
# we list all system-*-link symlinks, sort them numerically, and pick the one
# that immediately precedes the requested number using awk.
#
# IMPLEMENTATION NOTE
# ───────────────────
# We use `pkgs.writeShellApplication` instead of `writeShellScriptBin` because
# writeShellApplication:
#   1. Runs shellcheck at build time — catches bugs before you ever run the script
#   2. Sets `set -euo pipefail` automatically (strict mode)
#   3. Wraps runtimeInputs into PATH so the script is hermetic and reproducible
#      regardless of what is installed on the system at runtime
#
{ pkgs, ... }:
pkgs.writeShellApplication {
  name = "nixdiff";

  # These tools are injected into PATH only for this script's runtime.
  # nvd   — pretty coloured diff output (already in your repo via rebuild-and-diff)
  # nix   — provides `nix store diff-closures` as fallback
  # coreutils — ls, sort, tail
  # gawk  — awk one-liner for finding the predecessor generation
  runtimeInputs = with pkgs; [
    nvd
    nix
    coreutils
    gawk
  ];

  text = ''
    # ── constants ────────────────────────────────────────────────────────────
    PROFILES="/nix/var/nix/profiles"

    # ── helpers ──────────────────────────────────────────────────────────────

    # List all existing generation numbers, one per line, sorted ascending.
    # Example output:  75\n77\n78\n79
    list_gens() {
      ls -d "$PROFILES"/system-*-link 2>/dev/null \
        | sed 's|.*/system-||; s|-link$||' \
        | sort -n
    }

    # Return the full Nix store path for a given generation number.
    gen_path() {
      echo "$PROFILES/system-${1}-link"
    }

    # Given a generation number, return the highest existing generation that
    # is strictly less than it.  Prints nothing if there is no predecessor.
    gen_before() {
      list_gens | awk -v target="$1" '$1 < target { last=$1 } END { if (last) print last }'
    }

    # Validate that a generation symlink actually exists on disk.
    require_gen() {
      local p
      p=$(gen_path "$1")
      if [[ ! -e "$p" ]]; then
        echo "nixdiff: generation $1 not found (looked for $p)" >&2
        exit 1
      fi
    }

    # ── argument parsing ─────────────────────────────────────────────────────
    case $# in
      0)
        # No arguments: grab the last two generations automatically.
        mapfile -t LAST_TWO < <(list_gens | tail -2)
        if [[ ''${#LAST_TWO[@]} -lt 2 ]]; then
          echo "nixdiff: fewer than two generations exist — nothing to compare." >&2
          exit 1
        fi
        GEN_FROM="''${LAST_TWO[0]}"
        GEN_TO="''${LAST_TWO[1]}"
        ;;
      1)
        # One argument: treat it as the TO generation, find its predecessor.
        GEN_TO="$1"
        GEN_FROM=$(gen_before "$GEN_TO")
        if [[ -z "$GEN_FROM" ]]; then
          echo "nixdiff: no generation exists before generation $GEN_TO." >&2
          exit 1
        fi
        ;;
      2)
        # Two arguments: explicit FROM and TO.
        GEN_FROM="$1"
        GEN_TO="$2"
        ;;
      *)
        echo "Usage: nixdiff [FROM TO] | [TO] | []" >&2
        exit 1
        ;;
    esac

    # ── validation ───────────────────────────────────────────────────────────
    require_gen "$GEN_FROM"
    require_gen "$GEN_TO"

    PATH_FROM=$(gen_path "$GEN_FROM")
    PATH_TO=$(gen_path  "$GEN_TO")

    # ── output ───────────────────────────────────────────────────────────────
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "  NixOS Generation Diff"
    echo "  FROM → generation ''${GEN_FROM}  [ $PATH_FROM ]"
    echo "  TO   → generation ''${GEN_TO}  [ $PATH_TO ]"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""

    # nvd is the preferred frontend: colour output, explicit ADDED/REMOVED/UPGRADED.
    # It is always available here because it is in runtimeInputs.
    nvd diff "$PATH_FROM" "$PATH_TO"
  '';

  meta = with pkgs.lib; {
    description = "Compare two NixOS generations and show what was installed, updated or removed";
    license = licenses.mit;
    mainProgram = "nixdiff";
  };
}
