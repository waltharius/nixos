# users/marcin/desktop/gnome/solaar.nix
# Marcin's Solaar configuration for Logitech devices
#
# DEPENDENCY: Requires solaar-stable from apps.nix
{...}: {
  xdg.configFile."solaar/rules.yaml".text = ''
    %YAML 1.3
    ---
    # Rule 1: Zoom In using Thumb Wheel Up
    - Feature: THUMB WHEEL
    - Rule:
      - Test: [thumb_wheel_up, 6]
      - KeyPress:
        - Control_L
        - equal
    ...
    ---
    # Rule 2: Zoom Out using Thumb Wheel Down
    - Feature: THUMB WHEEL
    - Rule:
      - Test: [thumb_wheel_down, 6]
      - KeyPress:
        - Control_L
        - minus
    ...
    ---
    # Rule 3: Mouse Gesture - Move Left (Workspace Switch)
    - MouseGesture: Mouse Left
    - KeyPress:
      - Super_L
      - Alt_L
      - Left
    ...
    ---
    # Rule 4: Mouse Gesture - Move Right (Workspace Switch)
    - MouseGesture: Mouse Right
    - KeyPress:
      - Super_L
      - Alt_L
      - Right
    ...
    ---
    # Rule 5: Simple Click on Gesture Button -> Overview
    - Key: [Mouse Gesture Button, released]
    - KeyPress: Super_L
    ...
  '';

  xdg.configFile."solaar/config.yaml".text = ''
    %YAML 1.3
    ---
    - _NAME: MX Keys S
      _absent: [hi-res-scroll, lowres-scroll-mode, hires-smooth-invert, hires-smooth-resolution, hires-scroll-mode, scroll-ratchet, scroll-ratchet-torque, smart-shift,
        thumb-scroll-invert, thumb-scroll-mode, onboard_profiles, report_rate, report_rate_extended, pointer_speed, dpi, dpi_extended, speed-change, backlight-timed,
        led_control, led_zone_, rgb_control, rgb_zone_, brightness_control, per-key-lighting, reprogrammable-keys, persistent-remappable-keys, force-sensing,
        crown-smooth, divert-crown, divert-gkeys, m-key-leds, mr-key-led, gesture2-gestures, gesture2-divert, gesture2-params, haptic-level, haptic-play, sidetone,
        equalizer, adc_power_management]
      _battery: 4100
      _modelId: B37800000000
      _sensitive: {hires-scroll-mode: ignore, hires-smooth-invert: ignore, hires-smooth-resolution: ignore}
      _serial: B3177D71
      _unitId: B3177D71
      _wpid: B378
      backlight: 1
      backlight_duration_hands_in: 30
      backlight_duration_hands_out: 30
      backlight_duration_powered: 300
      backlight_level: 2
      change-host: null
      disable-keyboard-keys: {1: false, 2: false, 4: false, 8: false, 16: false}
      divert-keys: {10: 0, 111: 0, 199: 0, 200: 0, 226: 0, 227: 0, 228: 0, 229: 0, 230: 0, 231: 0, 232: 0, 233: 0, 234: 0, 259: 0, 264: 0, 266: 0, 284: 0}
      fn-swap: true
      multiplatform: 0
    - _NAME: MX Master 3S
      _absent: [hi-res-scroll, lowres-scroll-mode, scroll-ratchet-torque, onboard_profiles, report_rate, report_rate_extended, pointer_speed, dpi_extended,
        speed-change, backlight, backlight_level, backlight_duration_hands_out, backlight_duration_hands_in, backlight_duration_powered, backlight-timed, led_control,
        led_zone_, rgb_control, rgb_zone_, brightness_control, per-key-lighting, fn-swap, persistent-remappable-keys, disable-keyboard-keys, force-sensing,
        crown-smooth, divert-crown, divert-gkeys, m-key-leds, mr-key-led, multiplatform, gesture2-gestures, gesture2-divert, gesture2-params, haptic-level,
        haptic-play, sidetone, equalizer, adc_power_management]
      _battery: 4100
      _modelId: B03400000000
      _sensitive: {divert-keys: true, hires-scroll-mode: ignore, hires-smooth-invert: ignore, hires-smooth-resolution: ignore}
      _serial: 01777DA3
      _unitId: 01777DA3
      _wpid: B034
      change-host: null
      divert-keys: {82: 0, 83: 0, 86: 0, 195: 2, 196: 0}
      dpi: 1000
      hires-scroll-mode: false
      hires-smooth-invert: false
      hires-smooth-resolution: false
      reprogrammable-keys: {80: 80, 81: 81, 82: 82, 83: 83, 86: 86, 195: 195, 196: 196}
      scroll-ratchet: 2
      smart-shift: 10
      thumb-scroll-invert: false
      thumb-scroll-mode: true
  '';
}
