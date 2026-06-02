{ config, lib, pkgs, ... }:
let
  cfg      = config.marcin.desktop;
  desktops = lib.toList cfg;
  niri     = lib.elem "niri" desktops;
in
lib.mkIf niri {

  # ---------------------------------------------------------------------------
  # niri compositor
  # ---------------------------------------------------------------------------
  programs.niri.settings = {

    input = {
      keyboard = {
        xkb.layout  = "pl";
        xkb.options = "caps:escape";
        repeat-delay = 300;
        repeat-rate  = 50;
      };
      touchpad = {
        tap            = true;
        natural-scroll = true;
        dwt            = true;
        scroll-method  = "two-finger";
      };
      mouse.natural-scroll = false;
    };

    # Built-in 4K panel: scale 2.0 for crisp HiDPI rendering.
    # External monitors are auto-detected at 1.0 scale.
    # Override per-monitor if needed once you know the output names
    # (run `niri msg outputs` inside a running niri session).
    outputs."eDP-1".scale = 2.0;

    layout = {
      gaps = 8;
      center-focused-column = "never";
      preset-column-widths = [
        { proportion = 0.33; }
        { proportion = 0.5;  }
        { proportion = 0.67; }
      ];
      default-column-width = { proportion = 0.5; };

      # focus-ring schema (niri-flake 26.05):
      #   width   — separate numeric field, NOT inside active/inactive
      #   active  — attrTag: either { color = "…"; } or { gradient = {…}; }
      #   inactive — same attrTag type
      focus-ring = {
        enable   = true;
        width    = 2;
        active   = { color = "#7aa2f7"; };
        inactive = { color = "#3b4261"; };
      };

      border.enable = false;
    };

    animations.enable = true;

    window-rules = [
      { matches = [{ app-id = "org.gnome.Calculator"; }]; open-floating = true; }
      { matches = [{ app-id = "org.gnome.Nautilus";   }]; open-floating = true; }
      { matches = [{ title  = ".*[Pp]assword.*";       }]; open-floating = true; }
    ];

    # ---------------------------------------------------------------------------
    # Keybindings
    # ---------------------------------------------------------------------------
    binds = {
      # ── Applications ────────────────────────────────────────────────────────
      "Super+T".action.spawn       = [ "ptyxis" ];
      "Super+E".action.spawn       = [ "nautilus" ];
      "Super+F".action.spawn       = [ "brave" ];
      "Ctrl+Alt+E".action.spawn    = [ "emacs" ];
      "Ctrl+Q".action.spawn        = [ "signal-desktop" ];

      # ── Launcher ────────────────────────────────────────────────────────────
      "Super+D".action.spawn       = [ "rofi" "-show" "drun" ];
      "Super+Space".action.spawn   = [ "rofi" "-show" "drun" ];

      # ── Focus ───────────────────────────────────────────────────────────────
      "Super+H".action.focus-column-left  = {};
      "Super+L".action.focus-column-right = {};
      "Super+J".action.focus-window-down  = {};
      "Super+K".action.focus-window-up    = {};

      # ── Move ────────────────────────────────────────────────────────────────
      "Super+Shift+H".action.move-column-left  = {};
      "Super+Shift+L".action.move-column-right = {};
      "Super+Shift+J".action.move-window-down  = {};
      "Super+Shift+K".action.move-window-up    = {};

      # ── Resize ──────────────────────────────────────────────────────────────
      "Super+Ctrl+H".action.set-column-width  = "-10%";
      "Super+Ctrl+L".action.set-column-width  = "+10%";
      "Super+Ctrl+K".action.set-window-height = "-10%";
      "Super+Ctrl+J".action.set-window-height = "+10%";
      "Super+R".action.switch-preset-column-width = {};
      "Super+Shift+R".action.reset-window-height  = {};
      "Super+M".action.maximize-column            = {};
      "Super+Shift+M".action.fullscreen-window     = {};

      # ── Workspaces (1-4) ────────────────────────────────────────────────────
      "Super+1".action.focus-workspace = 1;
      "Super+2".action.focus-workspace = 2;
      "Super+3".action.focus-workspace = 3;
      "Super+4".action.focus-workspace = 4;
      "Super+Shift+1".action.move-window-to-workspace = 1;
      "Super+Shift+2".action.move-window-to-workspace = 2;
      "Super+Shift+3".action.move-window-to-workspace = 3;
      "Super+Shift+4".action.move-window-to-workspace = 4;

      # ── Workspace navigation ─────────────────────────────────────────────────
      "Super+W".action.focus-workspace-up   = {};
      "Super+S".action.focus-workspace-down = {};

      # ── Monitors ────────────────────────────────────────────────────────────
      "Super+Comma".action.focus-monitor-left         = {};
      "Super+Period".action.focus-monitor-right        = {};
      "Super+Shift+Comma".action.move-window-to-monitor-left  = {};
      "Super+Shift+Period".action.move-window-to-monitor-right = {};

      # ── Screenshot ──────────────────────────────────────────────────────────
      "Print".action.spawn       = [ "sh" "-c" ''grim -g "$(slurp)" - | wl-copy'' ];
      "Shift+Print".action.spawn = [ "sh" "-c" "grim - | wl-copy" ];

      # ── Window misc ─────────────────────────────────────────────────────────
      "Super+Q".action.close-window          = {};
      "Super+V".action.toggle-window-floating = {};
      "Super+C".action.center-column          = {};

      # ── System ──────────────────────────────────────────────────────────────
      "Super+Alt+L".action.spawn = [ "swaylock" ];
      "Super+Alt+Q".action.quit  = {};
    };
  };

  # ---------------------------------------------------------------------------
  # Waybar
  # ---------------------------------------------------------------------------
  programs.waybar = {
    enable = true;
    systemd.enable = true;

    settings = [{
      layer    = "top";
      position = "top";
      height   = 32;
      spacing  = 4;

      modules-left   = [ "niri/workspaces" "niri/window" ];
      modules-center = [ "clock" ];
      modules-right  = [ "pulseaudio" "network" "battery" "tray" ];

      "niri/workspaces".format = "{index}";
      "niri/window".max-length = 50;

      clock = {
        format         = "{:%a %d %b  %H:%M}";
        tooltip-format = "{:%Y-%m-%d %H:%M:%S}";
      };

      battery = {
        format       = "{capacity}% {icon}";
        format-icons = [ "" "" "" "" "" ];
        states       = { warning = 30; critical = 15; };
      };

      network = {
        format-wifi         = "{essid} ";
        format-ethernet     = "eth ";
        format-disconnected = "offline ";
        tooltip-format      = "{ifname} {ipaddr}/{cidr}";
      };

      pulseaudio = {
        format       = "{volume}% {icon}";
        format-muted = "muted ";
        format-icons = { default = [ "" "" "" ]; };
        on-click     = "pavucontrol";
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
  # Mako — notification daemon (HM 26.05 API)
  # ---------------------------------------------------------------------------
  # All visual options moved under services.mako.settings with kebab-case names.
  # The old camelCase top-level options (borderRadius, textColor, …) are
  # deprecated aliases that will eventually be removed.
  services.mako = {
    enable = true;
    settings = {
      default-timeout = 5000;
      layer           = "overlay";
      anchor          = "top-right";
      width           = 400;
      margin          = "8";
      padding         = "12";
      border-radius   = 6;
      border-size     = 1;
      background-color = "#1a1b26ee";
      text-color      = "#c0caf5";
      border-color    = "#3b4261";
      progress-color  = "over #7aa2f7";
      font            = "JetBrainsMono Nerd Font 12";
    };
    extraConfig = ''
      [urgency=high]
      border-color=#f7768e
      default-timeout=0
    '';
  };

  # ---------------------------------------------------------------------------
  # Rofi — application launcher (Wayland)
  # ---------------------------------------------------------------------------
  # Since nixpkgs 26.05, rofi-wayland has been merged into rofi.
  programs.rofi = {
    enable   = true;
    package  = pkgs.rofi;
    terminal = "ptyxis";
    theme    = "gruvbox-dark-soft";
    extraConfig = {
      modi               = "drun,run,window";
      show-icons         = true;
      drun-display-format = "{name}";
      window-format      = "{w} · {t}";
      kb-cancel          = "Escape,Super+d,Super+space";
    };
  };

  # ---------------------------------------------------------------------------
  # Swaylock — screen locker
  # ---------------------------------------------------------------------------
  programs.swaylock = {
    enable  = true;
    package = pkgs.swaylock;
    settings = {
      color               = "1a1b26";
      font                = "JetBrainsMono Nerd Font";
      indicator-radius    = 80;
      indicator-thickness = 4;
      ring-color          = "7aa2f7";
      key-hl-color        = "bb9af7";
      line-color          = "1a1b26";
      inside-color        = "1a1b26cc";
      separator-color     = "00000000";
      text-color          = "c0caf5";
      show-failed-attempts = true;
    };
  };

  # ---------------------------------------------------------------------------
  # Swayidle — idle management (HM 26.05 API)
  # ---------------------------------------------------------------------------
  # Breaking changes in HM 26.05:
  #   - systemdTarget (string)  →  systemdTargets (list of strings)
  #   - events (list of attrs)  →  events (attrset keyed by event name)
  services.swayidle = {
    enable         = true;
    # systemdTargets replaces the singular systemdTarget from HM < 26.05.
    systemdTargets = [ "niri.service" ];
    timeouts = [
      { timeout = 300; command = "${pkgs.swaylock}/bin/swaylock -f"; }
      { timeout = 600; command = "systemctl suspend"; }
    ];
    # events is now an attrset: { event-name = "command"; }
    events = {
      before-sleep = "${pkgs.swaylock}/bin/swaylock -f";
      lock         = "${pkgs.swaylock}/bin/swaylock -f";
    };
  };

  # ---------------------------------------------------------------------------
  # Polkit agent — GUI privilege dialogs in non-GNOME session
  # ---------------------------------------------------------------------------
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
