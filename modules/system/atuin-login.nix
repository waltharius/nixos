# modules/system/atuin-login.nix
#
# Logs admin accounts in to the Atuin server with the fleet's shared
# credentials from sops (secrets/atuin-password.txt, secrets/atuin-key.txt),
# one oneshot service per account: atuin-auto-login-<user>.
#
# Every host logs in with the same key, so no host can generate its own key
# and sync records nobody else can decrypt ('attempting to decrypt with
# incorrect key': sukkub on 2026-09-30, baal on 2026-10-02, both logged in
# by hand). Used by servers (base-baremetal.nix, base-lxc.nix: nixadm) and
# workstations (lib/classes.nix: marcin). keeper is left out: managed
# devices get a separate Atuin account (stage 6, BACKLOG.md).
#
# Each boot (and each deploy that changes the unit) the service:
#   - logged in already: compares the local key with the fleet key and
#     fails with exit code 3 when they differ. It does not repair anything:
#     a store with records under two keys needs the manual procedure
#     (store purge / push --force / pull --force, CHANGELOG 2026-09-30).
#   - not logged in: runs `atuin login` through expect with the password and
#     key from the credential files, then checks the key the same way.
# Network failures are retried every minute; a key mismatch (exit 3) is not.
#
# Secrets never appear on a command line (arguments of every process are
# world-readable in /proc/<pid>/cmdline): expect reads the credential files
# itself, and the key comparison goes through pipes.
{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  cfg = config.services.atuin-auto-login;

  # Expect script for the interactive `atuin login`.
  loginScript = pkgs.writeText "atuin-login.exp" ''
    proc readSecret {name} {
      set f [open "$::env(CREDENTIALS_DIRECTORY)/$name"]
      set value [string trimright [read $f] "\n"]
      close $f
      return $value
    }
    set password [readSecret atuin-password]
    set key [readSecret atuin-key]

    set timeout 30
    spawn ${pkgs.atuin}/bin/atuin login --username ${cfg.username}
    expect {
      -re {password.*:} {
        send -- "$password\r"
        exp_continue
      }
      -re {key.*:} {
        send -- "$key\r"
        exp_continue
      }
      eof {
        catch wait result
        exit [lindex $result 3]
      }
      timeout {
        puts "ERROR: Login timed out"
        exit 1
      }
    }
  '';

  loginService = pkgs.writeShellScript "atuin-auto-login" ''
    set -euo pipefail
    PATH=${makeBinPath [pkgs.atuin pkgs.expect pkgs.coreutils pkgs.diffutils]}

    if [ -z "''${CREDENTIALS_DIRECTORY:-}" ]; then
      echo "ERROR: CREDENTIALS_DIRECTORY not set" >&2
      exit 1
    fi
    key_file="$CREDENTIALS_DIRECTORY/atuin-key"
    if [ ! -r "$key_file" ] || [ ! -r "$CREDENTIALS_DIRECTORY/atuin-password" ]; then
      echo "ERROR: credential files not accessible" >&2
      exit 1
    fi

    # Atuin's default data directory (key, session, records.db).
    data_dir="$HOME/.local/share/atuin"
    mkdir -p "$data_dir"

    # Compares the local key with the fleet key without printing either.
    # `atuin key` and the sops file differ only by the trailing newline.
    key_matches() {
      cmp -s <(atuin key | tr -d '\n') <(tr -d '\n' < "$key_file")
    }

    mismatch() {
      echo "ERROR: $USER on this host uses an Atuin key different from secrets/atuin-key.txt." >&2
      echo "Its records cannot be decrypted by the other hosts. Stop the daemon" >&2
      echo "(systemctl --user stop atuin-daemon.socket atuin-daemon) and repair the" >&2
      echo "store as described in CHANGELOG.md (2026-09-30, Atuin)." >&2
      exit 3
    }

    if [ -e "$data_dir/session" ]; then
      if key_matches; then
        echo "Already logged in to Atuin with the fleet key"
        exit 0
      fi
      mismatch
    fi

    echo "Logging in to Atuin..."
    expect -f ${loginScript}

    if key_matches; then
      echo "Logged in to Atuin with the fleet key"
      exit 0
    fi
    mismatch
  '';

  # Accounts that exist on this host and share the fleet's Atuin account.
  defaultUsers = filter (u: config.users.users ? ${u}) ["marcin" "nixadm"];
in {
  options.services.atuin-auto-login = {
    enable = mkEnableOption "automatic Atuin login with the fleet credentials from sops";

    users = mkOption {
      type = types.listOf types.str;
      default = defaultUsers;
      defaultText = literalExpression ''the accounts among [ "marcin" "nixadm" ] that exist on the host'';
      description = "Accounts to log in to the Atuin server, one service each.";
    };

    username = mkOption {
      type = types.str;
      default = "admin";
      description = "Atuin server account";
    };
  };

  config = mkIf cfg.enable {
    # The password and key come from sops.
    services.secrets.enableAtuin = true;
    assertions = [
      {
        assertion = config.services.secrets.enable;
        message = "services.atuin-auto-login needs services.secrets.enable (sops-nix) on this host.";
      }
    ];

    environment.systemPackages = [pkgs.atuin pkgs.expect];

    systemd.services = listToAttrs (map (user: let
      home = config.users.users.${user}.home;
    in
      nameValuePair "atuin-auto-login-${user}" {
        description = "Log ${user} in to the Atuin server";
        after = ["network-online.target" "sops-nix.service"];
        wants = ["network-online.target"];
        wantedBy = ["multi-user.target"];

        serviceConfig = {
          Type = "oneshot";
          User = user;
          RemainAfterExit = true;
          Environment = "HOME=${home}";

          # Server unreachable (laptop offline, Wi-Fi not up yet): retry.
          # Key mismatch: no retry, see above.
          Restart = "on-failure";
          RestartSec = "1min";
          RestartPreventExitStatus = "3";

          LoadCredential = [
            "atuin-password:${config.sops.secrets.atuin-password.path}"
            "atuin-key:${config.sops.secrets.atuin-key.path}"
          ];

          NoNewPrivileges = true;
          PrivateTmp = true;
          ProtectSystem = "strict";
          ProtectHome = false;
          # The whole home: ~/.local/share/atuin may not exist yet on a
          # freshly installed host, and ReadWritePaths needs an existing
          # path.
          ReadWritePaths = home;

          ExecStart = "${loginService}";
        };
      })
    cfg.users);
  };
}
