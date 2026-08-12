# Weekly automatic system update.
#
# Order of operations (this is the part the old module got wrong):
#   1. nix flake update              -- refresh the lock file FIRST
#   2. git commit "OS update <date>" -- record exactly what will be built
#   3. nix flake check               -- optional gate
#   4. nixos-rebuild switch          -- build from a clean tree
#
# Generations produced here are labelled "up-YYYY-MM-DD". Manual rebuilds are
# left alone and keep the stock label (the nixpkgs version string), so the two
# are trivially distinguishable in the boot menu and in `list-generations`.
{
  config,
  lib,
  pkgs,
  ...
}: let
  repo = "/home/marcin/nixos";
  host = config.networking.hostName;

  # Run `nix flake check` before switching. Turn this off for the first few
  # test runs -- with no checks defined yet it only costs time, and once you
  # add runNixOSTest for Nextcloud/blog it becomes the actual quality gate.
  gateOnFlakeCheck = false;

  # Flake inputs to refresh. An empty list means "update everything".
  inputsToUpdate = [
    "nixpkgs"
    "nixpkgs-unstable"
    "home-manager"
    "sops-nix"
    "nixvim"
  ];

  upgradeScript = pkgs.writeShellApplication {
    name = "nixos-auto-upgrade";
    runtimeInputs = with pkgs; [git nix nixos-rebuild coreutils];
    text = ''
      cd ${repo}

      # This service runs as root against a repo in the user's home. Every object
      # nix or git writes here lands owned by root, which locks the user out of
      # their own repository. Hand ownership back on every exit path, including
      # the early aborts below.
      trap 'chown -R marcin:users ${repo}/.git ${repo}/flake.lock' EXIT

      # The repo lives in a user's home directory, so root has to be told it is
      # trusted. Scoped to this invocation rather than mutating root's global
      # gitconfig, and identity is supplied here so no global config is needed.
      gitc() {
        git \
          -c safe.directory=${repo} \
          -c user.name="NixOS Auto-Upgrade" \
          -c user.email="auto-upgrade@${host}" \
          "$@"
      }

      # Refuse to run on a dirty tree. An unattended job must never build or
      # commit half-finished manual edits. Untracked files are ignored.
      if [ -n "$(gitc status --porcelain --untracked-files=no)" ]; then
        echo "auto-upgrade: working tree is dirty, aborting" >&2
        exit 1
      fi

      DATE=$(date +%Y-%m-%d)

      # 1. Update the lock file.
      nix flake update ${lib.escapeShellArgs inputsToUpdate}

      # 2. Commit only flake.lock -- never 'git add -A' as root in a directory
      #    the user can write to.
      if ! gitc diff --quiet -- flake.lock; then
        gitc commit -m "OS update $DATE" -- flake.lock
      else
        echo "auto-upgrade: no input changes, rebuilding anyway"
      fi


      # 3. Gate on the flake's own checks. If the new inputs break evaluation
      #    or a runNixOSTest, stop here -- the commit stays, but the machine is
      #    not switched. Set gateOnFlakeCheck = false to skip while testing.
      if ${lib.boolToString gateOnFlakeCheck}; then
        if ! nix flake check --no-build; then
          echo "auto-upgrade: nix flake check failed, not switching" >&2
          exit 1
        fi
      fi

      # 4. Build and switch. NIXOS_LABEL is read at *evaluation* time by
      #    system.nixos.label (lib.maybeEnv), and builtins.getEnv returns ""
      #    under flake purity -- hence --impure. Manual rebuilds stay pure and
      #    therefore keep the default label.
      NIXOS_LABEL="up-$DATE" nixos-rebuild switch \
        --flake ${repo}#${host} \
        --impure \
        --print-build-logs
    '';
  };
in {
  systemd.services.nixos-auto-upgrade = {
    description = "Update flake inputs and switch to the new configuration";
    after = ["network-online.target"];
    wants = ["network-online.target"];
    onFailure = ["notify-upgrade-failure.service"];

    # Do not restart or stop this unit as part of the switch it is performing.
    restartIfChanged = false;
    unitConfig.X-StopOnRemoval = false;

    serviceConfig = {
      Type = "oneshot";
      ExecStart = lib.getExe upgradeScript;
      Environment = ["HOME=/root"];
    };
  };

  systemd.timers.nixos-auto-upgrade = {
    wantedBy = ["timers.target"];
    timerConfig = {
      OnCalendar = "weekly";
      Persistent = true; # catch up if the machine was off
      RandomizedDelaySec = "1h";
    };
  };

  systemd.services.notify-upgrade-failure = {
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${lib.getBin pkgs.libnotify}/bin/notify-send 'NixOS upgrade failed' 'Check journalctl -u nixos-auto-upgrade'";
      User = "marcin";
      # notify-send needs the session bus, not just DISPLAY. Adjust the UID if
      # marcin is not uid 1000.
      Environment = [
        "DISPLAY=:0"
        "DBUS_SESSION_BUS_ADDRESS=unix:path=/run/user/1000/bus"
      ];
    };
  };

  nix.gc = {
    automatic = true;
    dates = "monthly";
    options = "--delete-older-than 90d";
  };

  # auto-optimise-store and nix.optimise do the same job; keeping only the
  # scheduled one avoids paying the hashing cost on every single store write.
  nix.optimise = {
    automatic = true;
    dates = ["weekly"];
  };
}
