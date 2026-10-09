{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ../../modules/base.nix
    ../../modules/users.nix
    ../../modules/power.nix
    ../../modules/gpu-off.nix
    ../../modules/remote.nix
    ../../modules/claude.nix
  ];

  networking.hostName = "rognix";

  # Set at first install; don't change on upgrades.
  system.stateVersion = "26.05";
}
