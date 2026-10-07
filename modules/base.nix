{ ... }:
{
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 10;
  boot.loader.efi.canTouchEfiVariables = true;

  nix.settings = {
    experimental-features = [
      "nix-command"
      "flakes"
    ];
    trusted-users = [
      "root"
      "@wheel"
    ];
    auto-optimise-store = true;
  };
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  nixpkgs.config = {
    allowUnfree = true; # nvidia driver, Android SDK
    android_sdk.accept_license = true;
  };

  networking.networkmanager.enable = true;
  time.timeZone = "Europe/London";
  i18n.defaultLocale = "en_GB.UTF-8";
  console.keyMap = "uk";

  zramSwap.enable = true;

  # Lets prebuilt dynamic binaries run: Claude Code's native installer, Gradle's aapt2, etc.
  programs.nix-ld.enable = true;

  # Puts ~/.local/bin (where the Claude Code native installer lives) on PATH.
  environment.localBinInPath = true;
}
