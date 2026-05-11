{ ... }:

{
  # Framework 13 (Intel 12th/13th gen) ships the Goodix 27c6:60a2 fingerprint
  # sensor with factory firmware that libfprint cannot enrol against. fwupd
  # delivers the LVFS firmware update that makes the sensor usable; without it
  # KDE shows the enrolment UI but fprintd-enroll fails on the device.
  #
  # After rebuilding, run once as the regular user:
  #   fwupdmgr refresh
  #   fwupdmgr update
  # then reboot and enrol from System Settings -> Users -> Fingerprint.
  #
  # fprintd itself is enabled in modules/nixos/core/security.nix and PAM is
  # wired up by NixOS as soon as fprintd is on, so nothing else is needed here.
  services.fwupd.enable = true;
}
