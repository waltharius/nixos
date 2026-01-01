{pkgs, ...}: let
  # === CONFIGURATION SECTION ===
  themeName = "rings";
  logoPath = "${pkgs.nixos-icons}/share/icons/hicolor/128x128/apps/nix-snowflake-white.png";
  bottomPadding = "50";

  # === BUILD MODIFIED THEME PACKAGE ===
  # Step 1: Select only the theme we want
  baseThemePkg = pkgs.adi1090x-plymouth-themes.override {
    selected_themes = [themeName];
  };

  # Step 2: Inject our custom logo and script
  finalThemePkg = baseThemePkg.overrideAttrs (oldAttrs: {
    postInstall =
      (oldAttrs.postInstall or "")
      + ''
              THEME_DIR="$out/share/plymouth/themes/${themeName}"
              SCRIPT_FILE="$THEME_DIR/${themeName}.script"

              # Copy logo
              cp ${logoPath} $THEME_DIR/watermark.png

              # Append logo display code to the theme script
              cat >> $SCRIPT_FILE <<'EOF'

        # --- Custom Logo (Added by NixOS) ---
        watermark_image = Image("watermark.png");
        if (watermark_image) {
          wm_sprite = Sprite(watermark_image);
          wm_sprite.SetX(Window.GetX() + (Window.GetWidth() / 2 - watermark_image.GetWidth() / 2));
          wm_sprite.SetY(Window.GetHeight() - watermark_image.GetHeight() - ${bottomPadding});
          wm_sprite.SetZ(10000);
        }
        # ------------------------------------
        EOF
      '';
  });
in {
  boot = {
    plymouth = {
      enable = true;
      theme = themeName;
      themePackages = [finalThemePkg];
    };

    # Quiet boot settings
    consoleLogLevel = 0;
    initrd.verbose = false;

    kernelParams = [
      "quiet"
      "splash"
      "boot.shell_on_fail"
      "loglevel=3"
      "rd.systemd.show_status=false"
      "rd.udev.log_level=3"
      "udev.log_priority=3"
    ];

    initrd.systemd.enable = true;
  };
}
