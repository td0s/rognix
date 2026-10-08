{ ... }:
{
  users.groups.adbusers = { };

  users.users.claude = {
    isNormalUser = true;
    description = "Claude Code agent";
    extraGroups = [
      "wheel"
      "kvm" # Android emulator acceleration
      "adbusers" # USB adb, see udev rule below
      "networkmanager"
    ];
    # Add your phone/laptop SSH public keys here (used over Tailscale only).
    openssh.authorizedKeys.keys = ["ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmICF//KAuQ+UXOzcSyMDhSi0J+gM++JEmdXlNExTzB" ];
  };

  # The device itself is the sandbox; Claude gets passwordless root.
  security.sudo.wheelNeedsPassword = false;

  # Android devices expose an ADB interface (class ff, subclass 42, protocol 01).
  # systemd's uaccess only covers seat users, not the headless service user.
  services.udev.extraRules = ''
    SUBSYSTEM=="usb", ENV{ID_USB_INTERFACES}=="*:ff4201:*", MODE="0660", GROUP="adbusers"
  '';
}
