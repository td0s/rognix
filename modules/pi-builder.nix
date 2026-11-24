{ ... }:
{
  # Build aarch64 (Raspberry Pi) systems here through QEMU user emulation.
  boot.binfmt.emulatedSystems = [ "aarch64-linux" ];
  boot.binfmt.preferStaticEmulators = true;

  # Prebuilt Raspberry Pi kernels and firmware for nixos-raspberrypi.
  nix.settings.extra-substituters = [ "https://nixos-raspberrypi.cachix.org" ];
  nix.settings.extra-trusted-public-keys = [
    "nixos-raspberrypi.cachix.org-1:4iMO9LXa8BqhU+Rpg6LQKiGa2lsNh/j2oiYLNOQ5sPI="
  ];
}
