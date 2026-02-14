# Thunderbolt 3 support for docking stations
{pkgs, ...}: {
  # Enable Thunderbolt support
  services.hardware.bolt.enable = true;

  # Add thunderbolt management tool
  environment.systemPackages = with pkgs; [
    bolt # Thunderbolt device management
  ];
  # KNOWN ISSUE: ThinkPad TB3 Dock Gen 2 + Meteor Lake CPU
  # DisplayPort tunnels fail to initialize on cold boot when dock is connected.
  #
  # WORKAROUND: Either:
  # 1. Connect dock AFTER system finishes booting (5 seconds delay)
  # 2. Leave dock permanently connected between reboots
  #
  # If monitors not detected after boot:
  # - Unplug dock, wait 3 seconds, replug, but this is not working in my situation
  # - OR switch to other USB-C port, then switch back
  #
  # Root cause: Hardware timing issue in dock firmware during DP MST initialization
  # Status: No software fix available, affects multiple Linux users
  # References:
  #  1. **Arch Linux Forum: Thunderbolt dock not awake on resume** [bbs.archlinux](https://bbs.archlinux.org/viewtopic.php?id=286662)
  #   - Same issue: monitors and USB not working after resume
  #   - ThinkPad T480s with Thunderbolt 3 dock
  #
  # 2. **Arch Linux Forum: External monitors not detected on boot/resume** [bbs.archlinux](https://bbs.archlinux.org/viewtopic.php?id=280771)
  #   - ThinkPad P1 Gen 2 and Gen 5 with TB4 dock
  #   - Exact symptom: disconnect/reconnect cable fixes it
  #   - USB works but displays don't
  #
  # 3. **Fedora Discussion: No USB devices on docking station after suspend** [discussion.fedoraproject](https://discussion.fedoraproject.org/t/no-usb-devices-on-docking-station-when-resuming-from-suspend/110498)
  #   - Workaround: "Open laptop, unplug dock, unlock OS, replug dock"
  #   - Same pattern you're experiencing
  #
  # 4. **NVIDIA Forums: External monitor not available after suspend** [forums.developer.nvidia](https://forums.developer.nvidia.com/t/external-monitor-not-available-after-suspend-sleep/189397)
  #   - ThinkPad P1 Gen2 with Thunderbolt 3 Workstation Dock
  #   - "Dock authorized, other devices work, but monitors not recognized"
  #   - **Your exact issue!**
  #
  # 5. **Kernel Bugzilla #201255: ThinkPad T480s TB3 dock USB doesn't work after resume** [bugzilla.kernel](https://bugzilla.kernel.org/show_bug.cgi?id=201255)
  #   - Fedora 29, kernel 4.18/4.19
  #   - "Replugging the dock fixes the issue"
  #   - Long-standing kernel bug
  #
  # 6. **Reddit: Thunderbolt keeps putting itself to sleep** [reddit](https://www.reddit.com/r/linuxquestions/comments/1j97vfz/thunderbolt_keeps_randomly_putting_itself_to/)
  #   - Power state transitions D0→D3hot causing device to become unreachable
  #   - "Unable to change power state from D0 to D3hot, device inaccessible"
  #   - **Exactly your UPower "?" issue**
  #
  #### Technical Documentation
  #
  # 7. **Frame.work Community: TB4 dock wake from sleep issues** [community.frame](https://community.frame.work/t/tb4-dock-issues-with-wake-from-sleep-workaround-s2idle-vs-deep-and-firmware-question-11-gen/26619)
  #   - Discussion of s2idle vs deep sleep modes
  #   - s2idle works better with Thunderbolt docks
  #   - Firmware updates sometimes help
  #
  # 8. **XMG Reddit: How to fix TB3 dock USB issues** [reddit](https://www.reddit.com/r/XMG_gg/comments/ic7vt7/fusion15_linux_how_to_fix_thunderbolttb3_dock_usb/)
  #   - Kernel parameter workaround: `pci=realloc,assign-busses`
  #   - **Warning**: Breaks standby mode - relevant to your case!
  #
  # 9. **Arch Linux: Thunderbolt 3 dock hotplug/suspend issues** [bbs.archlinux](https://bbs.archlinux.org/viewtopic.php?id=264134)
  #   - Dell XPS 9500
  #   - "Hardware fine on fresh boot, but kernel cannot handle unplug/replug"
  #
  #### Official Documentation
  #
  # 10. **Linux Kernel: Dynamic Debug Documentation** [docs.kernel](https://docs.kernel.org/admin-guide/dynamic-debug-howto.html)
  #    - How to use dyndbg parameters
  #    - https://docs.kernel.org/admin-guide/dynamic-debug-howto.html
  #
  # 11. **Systemd: Inhibitor Locks** [systemd](https://systemd.io/INHIBITOR_LOCKS/)
  #    - https://systemd.io/INHIBITOR_LOCKS/
  #
  # 12. **TLP Documentation: Radio Device Wizard** [linrunner](https://linrunner.de/tlp/settings/rdw.html)
  #    - https://linrunner.de/tlp/settings/rdw.html
  #
  # 13. **Freedesktop: logind.conf manual** [freedesktop](https://www.freedesktop.org/software/systemd/man/logind.conf.html)
  #    - https://www.freedesktop.org/software/systemd/man/logind.conf.html
  #
  ### Key Takeaways from Research
  #
  #The consensus across all these reports: [bbs.archlinux](https://bbs.archlinux.org/viewtopic.php?id=286662)
  #
  # 1. **This is a widespread Linux + Thunderbolt dock issue**, especially with ThinkPad docks
  # 2. **Root cause**: Power state (D0/D3) transitions during hibernate corrupt the PCIe/Thunderbolt state
  # 3. **Display DP/HDMI outputs are most affected** - they don't reinitialize after hibernate
  # 4. **USB devices often work** after resume (you confirmed this)
  # 5. **Workaround**: Unplug/replug Thunderbolt cable after resume (you're already doing this)
  # 6. **Better solution**: Avoid hibernating while docked - use suspend instead
}
