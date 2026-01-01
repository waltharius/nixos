{pkgs, ...}: let
  # === CONFIGURATION SECTION ===
  # This section is for customizing boot screen change and appending NixOS logo icon
  # just make changes here, not in the rest of the script. Changing themeName and customLogoPath
  # will be taken via rest of the script and rebuild accordingly. customLogoPath must be the full
  # patch to logo with the logo name itself.
  themeName = "rings";
  customLogoPath = "${pkgs.nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake.png";
  logoPadding = "50";
in {
  boot = {
    plymouth = {
      enable = true;

      # Using variable defined above
      theme = themeName;

      # === Theme Configuration ===

      # Install the theme package with overrie to install onlsy specyfic themes
      # Complete package is HUGE
      # To download and check without installing run:
      # nix-shell -p adi1090x-plymouth-themes --run "ls $(nix-build '<nixpkgs>' -A adi1090x-plymouth-themes --no-out-link)/share/plymouth/themes"

      themePackages = [
        (pkgs.adi1090x-plymouth-themes.override {
          selected_themes = [themeName];
        }).overrideAttrs
        (oldAttrs: {
          # Append custom logic to the postInstall phase
          postInstall =
            (oldAttrs.postInstall or "")
            + ''
              # Dynamic variables from Nix 'let' block
              THEME_NAME="${themeName}"
              THEME_DIR="$out/share/plymouth/themes/$THEME_NAME"

              # Safety check: Ensure the theme directory actually exists
              if [ ! -d "$THEME_DIR" ]; then
                echo "ERROR: Theme '$THEME_NAME' not found in $out/share/plymouth/themes/"
                echo "Available themes:"
                ls "$out/share/plymouth/themes/"
                exit 1
              fi

              # 1. Copy the custom logo to the theme directory
              cp ${customLogoPath} $THEME_DIR/watermark.png

              # 2. Patch the theme's .script file dynamically
              # Look for the main script file, which is usually named <themeName>.script
              SCRIPT_FILE="$THEME_DIR/$THEME_NAME.script"

              if [ ! -f "$SCRIPT_FILE" ]; then
                echo "ERROR: Script file not found at $SCRIPT_FILE"
                exit 1
              fi

              # Append the logo logic to the end of the script
              cat >> $SCRIPT_FILE <<'EOF'

              # --- Custom Logo Logic (Added by NixOS) ---
              # Load the watermark image
              watermark_image = Image("watermark.png");

              # Only proceed if image loaded successfully (prevents crash if missing)
              if (watermark_image) {
                watermark_sprite = Sprite();
                watermark_sprite.SetImage(watermark_image);

                # Center Horizontally: (Screen Width / 2) - (Image Width / 2)
                watermark_sprite.SetX(Window.GetX() + (Window.GetWidth() / 2 - watermark_image.GetWidth() / 2));

                # Position at Bottom: Screen Height - Image Height - Padding
                watermark_sprite.SetY(Window.GetHeight() - watermark_image.GetHeight() - ${logoPadding});

                # Ensure it's on top of background but below dialogs (Z=10000 is usually safe)
                watermark_sprite.SetZ(10000);
              }
              # ------------------------------------------
              EOF
            '';
        })
      ];
    };
    # Optional font or logo
    # font = "${pkgs.hack-font}/share/fonts/truetype/Hack-Regular.ttf";
    # logo = "${pkgs.nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake.png";

    # === Logging Configuration ===

    # Log levels:
    # 0 (Emergency) - nearly nothing is shown
    # 3 (Errors) - standdard level
    # 4 (Warnings) - default in many distros
    # 7 (Debug) - everything is logged
    # Silencing to 0 to avoid overwriteing spash screen
    consoleLogLevel = 0;

    # For clean graphical experience disable verbose logging fromthe
    # the initial ramdisk (initrd)
    initrd.verbose = false;

    # Plymuth requires systemd to be enabled in the initrd phase
    # to function correctly with LUKS passphrase prompt
    initrd.systemd.enable = true;

    # KERNEL PARAMS
    # "quiet"  -> Tells the kernel to suppress most log messages
    # "splash" -> Tells the system to start Plymouth immediately
    # "boot.shell_on_fail" -> Drops to a recovery shell if boot fails (useful for debugging)
    # "rd.systemd.show_status=false" -> Hides systemd status messages (OK, FAILED) initially.
    #    NOTE: Even with this set to false, pressing 'Esc' during boot
    #    should toggle the text console view where you can see what's happening.
    # "rd.udev.log_level=3" -> Limits udev (hardware detection) logging to errors only.
    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];
  };
}
