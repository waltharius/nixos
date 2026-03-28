# hosts/physical/altair/disko.nix
#
# Declarative disk layout for altair
# Board:  ASUS ProArt X870E-CREATOR WIFI (AM5)
# CPU:    AMD Ryzen 9 7900 (Zen 4, 12C/24T)
#
# Disks:
#   main  — WD SN850X 2TB NVMe  (M.2_1, PCIe 5.0 x4, CPU-direct)
#   data  — Toshiba N300 14TB   (SATA via ASM1064 controller)
#
# ⚠️  CRITICAL: M.2_2 slot MUST remain EMPTY with dual-GPU config.
#     Populating M.2_2 drops PCIe slot 2 from x8 → x4 (ASUS X870E bifurcation).
#
# LUKS2 parameters:
#   --cipher aes-xts-plain64  : XTS mode, standard for block-device encryption
#   --key-size 512            : 512-bit total = XTS-AES-256 (256 bits per subkey)
#   --pbkdf argon2id          : Memory-hard KDF (PHC winner 2015); resists GPU brute-force
#   --pbkdf-memory 524288     : 512 MB RAM per attempt — limits parallel GPU attacks
#   --pbkdf-parallel 4        : Matches CPU threads; maximises attacker cost
#   Result: attacker with 4× RTX 3090 ≈ 0.1 passwords/second/GPU
#
# Stage 1 note (Tang/Clevis deferred):
#   Slot 0 = recovery passphrase (paper, offline)
#   Slot 1, 2 = Clevis/Tang binding — added AFTER GPU verification (Phase 0 work)
#
# To reinstall from scratch:
#   1. Boot NixOS live USB
#   2. git clone https://github.com/waltharius/nixos /tmp/nixos
#   3. read -rs PASS; echo -n "$PASS" > /tmp/disk-password
#   4. nix run github:nix-community/disko -- --mode disko /tmp/nixos/hosts/physical/altair/disko.nix
#   5. nixos-install --flake /tmp/nixos#altair
{...}: {
  disko.devices = {
    disk = {
      # ==========================================================================
      # MAIN DISK — WD Black SN850X 2TB NVMe
      # Slot: M.2_1 (PCIe 5.0 x4, CPU-direct lanes)
      # Confirmed ID: nvme-WD_BLACK_SN850X_2000GB_25503L800955
      # ==========================================================================
      main = {
        type = "disk";
        device = "/dev/disk/by-id/nvme-WD_BLACK_SN850X_2000GB_25503L800955";
        content = {
          type = "gpt";
          partitions = {
            # EFI System Partition — 1 GB
            ESP = {
              size = "1G";
              type = "EF00";
              content = {
                type = "filesystem";
                format = "vfat";
                mountpoint = "/boot";
                mountOptions = [
                  "umask=0077"
                  "defaults"
                ];
              };
            };

            # Root partition — remainder of NVMe
            root = {
              size = "100%";
              content = {
                type = "luks";
                name = "cryptroot";
                passwordFile = "/tmp/disk-password";
                settings = {
                  allowDiscards = true;
                  bypassWorkqueues = true;
                };
                extraFormatArgs = [
                  "--type"
                  "luks2"
                  "--cipher"
                  "aes-xts-plain64"
                  "--key-size"
                  "512"
                  "--pbkdf"
                  "argon2id"
                  "--pbkdf-memory"
                  "524288"
                  "--pbkdf-parallel"
                  "4"
                  "--label"
                  "cryptroot"
                ];
                content = {
                  type = "btrfs";
                  extraArgs = ["-L" "nixos" "-f"];
                  subvolumes = {
                    "@" = {
                      mountpoint = "/";
                      mountOptions = ["compress=zstd" "noatime" "space_cache=v2" "subvol=@"];
                    };
                    "@home" = {
                      mountpoint = "/home";
                      mountOptions = ["compress=zstd" "noatime" "space_cache=v2" "subvol=@home"];
                    };
                    "@nix" = {
                      mountpoint = "/nix";
                      mountOptions = ["compress=zstd" "noatime" "space_cache=v2" "subvol=@nix"];
                    };
                    "@snapshots" = {
                      mountpoint = "/.snapshots";
                      mountOptions = ["compress=zstd" "noatime" "space_cache=v2" "subvol=@snapshots"];
                    };
                  };
                };
              };
            };
          };
        };
      };

      # ==========================================================================
      # DATA DISK — Toshiba N300 14TB (SATA)
      # Confirmed ID: ata-TOSHIBA_HDWG51EUZSVA_8562A02HFQ6H
      # ==========================================================================
      data = {
        type = "disk";
        device = "/dev/disk/by-id/ata-TOSHIBA_HDWG51EUZSVA_8562A02HFQ6H";
        content = {
          type = "gpt";
          partitions = {
            data = {
              size = "100%";
              type = "8300";
              content = {
                type = "luks";
                name = "cryptdata";
                passwordFile = "/tmp/disk-password";
                settings = {
                  allowDiscards = false;
                };
                extraFormatArgs = [
                  "--type"
                  "luks2"
                  "--cipher"
                  "aes-xts-plain64"
                  "--key-size"
                  "512"
                  "--pbkdf"
                  "argon2id"
                  "--pbkdf-memory"
                  "524288"
                  "--pbkdf-parallel"
                  "4"
                  "--label"
                  "cryptdata"
                ];
                content = {
                  type = "btrfs";
                  extraArgs = ["-L" "data" "-f"];
                  subvolumes = {
                    "@data" = {
                      mountpoint = "/mnt/data";
                      mountOptions = ["compress=zstd:3" "noatime" "autodefrag" "space_cache=v2" "subvol=@data"];
                    };
                  };
                };
              };
            };
          };
        };
      };
    };
  };
}
