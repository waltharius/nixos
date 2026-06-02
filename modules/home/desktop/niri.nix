# modules/home/desktop/niri.nix
#
# Home Manager configuration for the niri Wayland compositor session.
#
# Includes:
#   programs.niri        — niri config.kdl (keybindings, layout, outputs)
#   programs.waybar      — minimal top bar (workspaces, clock, system tray)
#   services.mako        — notification daemon
#   programs.rofi        — application launcher (wayland variant)
#   programs.swaylock    — screen locker
#   services.swayidle    — idle manager: lock after 5 min, suspend after 10 min
#
# This file is imported by users/marcin/base/desktop-extensions.nix when
# "niri" is present in marcin.desktop. Do not import it directly.
{ pkgs, lib, ... }: {

  # ---------------------------------------------------------------------------
  # niri compositor configuration
  # ---------------------------------------------------------------------------
  programs.niri = {
    settings = {
      # --- input ---
      input = {
        keyboard = {
          xkb.layout  = "pl";
          xkb.options = "caps:escape";   # Caps Lock acts as Escape
          repeat-delay = 300;
          repeat-rate  = 50;
        };
        touchpad = {
          tap                 = true;   # tap to click
          natural-scroll      = true;
          dwt                 = true;   # disable while typing
          scroll-method       = "two-finger";
        };
        mouse.natural-scroll  = false;
      };

      # --- outputs ---
      # niri auto-detects connected outputs. We set scale for the built-in
      # 4K panel; external monitors are left at default (1.0) so they work
      # at any resolution without manual config changes.
      outputs."eDP-1" = {
        scale = 2.0;   # HiDPI for built-in 4K panel
        # Remove or override in profiles/sukkub.nix if you prefer a
        # different scale.
      };

      # --- layout ---
      layout = {
        gaps             = 8;
        center-focused-column = "never";
        preset-column-widths  = [
          { proportion = 0.33; }
          { proportion = 0.5;  }
          { proportion = 0.67; }
        ];
        default-column-width  = { proportion = 0.5; };

        focus-ring = {
          enable = true;
          width  = 2;
          active-color   = "#7aa2f7";   # Tokyo Night blue
          inactive-color = "#3b4261";
        };
        border.enable = false;   # use focus-ring only, no extra border
      };

      # --- animations ---
      # Keep animations on — they help with spatial orientation in a tiling WM.
      # Set to false if you experience tearing on NVIDIA.
      animations.enable = true;

      # --- window rules ---
      window-rules = [
        # Float small utility dialogs
        {
          matches = [{ app-id = "org.gnome.Calculator"; }];
          open-floating = true;
        }
        {
          matches = [{ app-id = "org.gnome.Nautilus"; }];
          open-floating = true;
          default-column-width = { proportion = 0.5; };
        }
        {
          matches = [{ title = ".*[Pp]assword.*"; }];
          open-floating = true;
        }
      ];

      # --- keybindings ---
      # Convention: Super = window manager actions
      #             Super+Shift = move/swap actions
      #             Super+Ctrl  = layout/resize actions
      #             Super+Alt   = system actions (quit, lock)
      binds = with builtins; {
        # Applications (mirrors run-or-raise shortcuts from GNOME)
        "Super+T".action.spawn         = [ "ptyxis" ];
        "Super+E".action.spawn         = [ "nautilus" ];
        "Super+F".action.spawn         = [ "brave" ];
        "Ctrl+Alt+E".action.spawn      = [ "emacs" ];
        "Ctrl+Q".action.spawn          = [ "signal-desktop" ];

        # Launcher
        "Super+D".action.spawn         = [ "rofi" "-show" "drun" ];
        "Super+Space".action.spawn     = [ "rofi" "-show" "drun" ];

        # Window management
        "Super+Q".action                = "close-window";
        "Super+H".action                = "focus-column-left";
        "Super+L".action                = "focus-column-right";
        "Super+J".action                = "focus-window-down";
        "Super+K".action                = "focus-window-up";
        "Super+Shift+H".action          = "move-column-left";
        "Super+Shift+L".action          = "move-column-right";
        "Super+Shift+J".action          = "move-window-down";
        "Super+Shift+K".action          = "move-window-up";

        # Resize (Ctrl+Super)
        "Super+Ctrl+H".action           = "set-column-width -10%";
        "Super+Ctrl+L".action           = "set-column-width +10%";
        "Super+Ctrl+K".action           = "set-window-height -10%";
        "Super+Ctrl+J".action           = "set-window-height +10%";
        "Super+R".action                = "switch-preset-column-width";
        "Super+Shift+R".action          = "reset-window-height";
        "Super+M".action                = "maximize-column";
        "Super+Shift+M".action          = "fullscreen-window";

        # Column widths
        "Super+1".action                = "set-column-width 33%";
        "Super+2".action                = "set-column-width 50%";
        "Super+3".action                = "set-column-width 67%";
        "Super+4".action                = "set-column-width 100%";

        # Workspaces
        "Super+W".action                = "focus-workspace-up";
        "Super+S".action                = "focus-workspace-down";
        "Super+Shift+W".action          = "move-window-to-workspace-up";
        "Super+Shift+S".action          = "move-window-to-workspace-down";

        # Overview (equivalent of GNOME Activities)
        "Super+O".action                = "toggle-overview";
        "Super+grave".action            = "toggle-overview";  # Super+`

        # Monitors
        "Super+Comma".action            = "focus-monitor-left";
        "Super+Period".action           = "focus-monitor-right";
        "Super+Shift+Comma".action      = "move-window-to-monitor-left";
        "Super+Shift+Period".action     = "move-window-to-monitor-right";

        # Screenshot
        "Print".action.spawn            = [ "sh" "-c" "grim -g \"$(slurp)\" - | wl-copy" ];
        "Shift+Print".action.spawn      = [ "sh" "-c" "grim - | wl-copy" ];

        # Lock screen
        "Super+Alt+L".action.spawn      = [ "swaylock" ];

        # Exit niri (back to GDM)
        "Super+Alt+Q".action            = "quit";

        # Floating toggle
        "Super+V".action                = "toggle-window-floating";
        "Super+C".action                = "center-column";
      };
    };
  };

  # ---------------------------------------------------------------------------
  # Waybar — minimal top bar
  # ---------------------------------------------------------------------------
  programs.waybar = {
    enable  = true;
    systemd.enable = true;  # start waybar as a systemd user service

    settings = [{
      layer    = "top";
      position = "top";
      height   = 32;
      spacing  = 4;

      modules-left   = [ "niri/workspaces" "niri/window" ];
      modules-center = [ "clock" ];
      modules-right  = [
        "pulseaudio"
        "network"
        "battery"
        "tray"
      ];

      "niri/workspaces" = {
        format = "{index}";
      };

      "niri/window" = {
        max-length = 50;
      };

      clock = {
        format     = "{:%a %d %b  %H:%M}";
        tooltip-format = "{:%Y-%m-%d %H:%M:%S}";
      };

      battery = {
        format          = "{capacity}% {icon}";
        format-icons    = [ "" "" "" "" "" ];
        states.warning  = 30;
        states.critical = 15;
      };

      network = {
        format-wifi         = "{essid} ";
        format-ethernet     = "eth ";
        format-disconnected = "disconnected ";
        tooltip-format      = "{ifname} {ipaddr}/{cidr}";
      };

      pulseaudio = {
        format        = "{volume}% {icon}";
        format-muted  = "muted ";
        format-icons  = { default = [ "" "" "" ]; };
        on-click      = "pavucontrol";
      };

      tray.spacing = 8;
    }];

    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 13px;
      }
      window#waybar {
        background-color: rgba(26, 27, 38, 0.95);
        color: #c0caf5;
        border-bottom: 1px solid #3b4261;
      }
      #workspaces button {
        padding: 0 6px;
        color: #565f89;
        border-radius: 4px;
      }
      #workspaces button.active {
        color: #7aa2f7;
        background: rgba(122, 162, 247, 0.15);
      }
      #clock, #battery, #network, #pulseaudio, #tray {
        padding: 0 10px;
        color: #c0caf5;
      }
      #battery.warning  { color: #e0af68; }
      #battery.critical { color: #f7768e; }
    '';
  };

  # ---------------------------------------------------------------------------
  # Mako — notification daemon
  # ---------------------------------------------------------------------------
  services.mako = {
    enable            = true;
    defaultTimeout    = 5000;
    layer             = "overlay";
    anchor            = "top-right";
    width             = 400;
    margin            = "8";
    padding           = "12";
    borderRadius      = 6;
    borderSize        = 1;
    backgroundColor   = "#1a1b26ee";
    textColor         = "#c0caf5";
    borderColor       = "#3b4261";
    progressColor     = "over #7aa2f7";
    font              = "JetBrainsMono Nerd Font 12";
    extraConfig = ''
      [urgency=high]
      border-color=#f7768e
      default-timeout=0
    '';
  };

  # ---------------------------------------------------------------------------
  # Rofi — application launcher (Wayland)
  # ---------------------------------------------------------------------------
  programs.rofi = {
    enable     = true;
    package    = pkgs.rofi-wayland;
    terminal   = "ptyxis";
    theme      = "gruvbox-dark-soft";   # built-in theme, dark and clean
    extraConfig = {
      modi            = "drun,run,window";
      show-icons      = true;
      drun-display-format = "{name}";
      window-format   = "{w} · {t}";
      kb-cancel        = "Escape,Super+d,Super+space";
    };
  };

  # ---------------------------------------------------------------------------
  # Swaylock — screen locker
  # ---------------------------------------------------------------------------
  programs.swaylock = {
    enable   = true;
    package  = pkgs.swaylock;
    settings = {
      color            = "1a1b26";   # solid dark background (Tokyo Night)
      font             = "JetBrainsMono Nerd Font";
      indicator-radius = 80;
      indicator-thickness = 4;
      ring-color       = "7aa2f7";
      key-hl-color     = "bb9af7";
      line-color       = "1a1b26";
      inside-color     = "1a1b26cc";
      separator-color  = "00000000";
      text-color       = "c0caf5";
      show-failed-attempts = true;
    };
  };

  # ---------------------------------------------------------------------------
  # Swayidle — idle management
  # ---------------------------------------------------------------------------
  # Timeline:
  #   5 min idle  → lock screen (swaylock)
  #  10 min idle  → suspend (systemctl suspend)
  #  on lock      → turn off displays after 10 s
  #  on wake      → turn displays back on
  services.swayidle = {
    enable = true;
    systemdTarget = "niri.service";   # start only inside niri session
    timeouts = [
      {
        timeout = 300;  # 5 min
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
      {
        timeout = 600;  # 10 min
        command = "systemctl suspend";
      }
    ];
    events = [
      {
        event   = "before-sleep";
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
      {
        event   = "lock";
        command = "${pkgs.swaylock}/bin/swaylock -f";
      }
    ];
  };

  # ---------------------------------------------------------------------------
  # Polkit authentication agent
  # ---------------------------------------------------------------------------
  # Starts the GNOME polkit agent so GUI apps (e.g. Flatpak, Nextcloud)
  # can ask for your password in a proper dialog instead of failing silently.
  systemd.user.services.polkit-agent = {
    Unit = {
      Description = "Polkit authentication agent";
      After       = "niri.service";
      PartOf      = "niri.service";
    };
    Service = {
      ExecStart = "${pkgs.polkit_gnome}/libexec/polkit-gnome-authentication-agent-1";
      Restart   = "on-failure";
    };
    Install.WantedBy = [ "niri.service" ];
  };
}
