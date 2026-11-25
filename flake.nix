{
  description = "rognix: disposable NixOS box for phone-controlled Claude Code (ASUS ROG Zephyrus GX501)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

    # Raspberry Pi support. Don't make its nixpkgs follow ours: its binary
    # cache (prebuilt Pi kernels) only matches its own nixpkgs.
    nixos-raspberrypi.url = "github:nvmd/nixos-raspberrypi/main";

    # Switch to "github:td0s/pi-lite-eq" once the nix-module branch is merged.
    pi-lite-eq.url = "path:/home/claude/projects/pi-lite-eq";
  };

  outputs =
    inputs@{ self, nixpkgs, nixos-raspberrypi, pi-lite-eq, ... }:
    {
      nixosConfigurations.rognix = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/rognix/configuration.nix ];
      };

      # Raspberry Pi 3 Model B: Pi-Lite EQ meter + Music Assistant Alexa skill.
      # SD image: nix build .#nixosConfigurations.pi.config.system.build.sdImage
      nixosConfigurations.pi = nixos-raspberrypi.lib.nixosSystem {
        specialArgs = inputs;
        modules = [
          nixos-raspberrypi.nixosModules.raspberry-pi-3.base
          nixos-raspberrypi.nixosModules.sd-image
          pi-lite-eq.nixosModules.default
          ./hosts/pi
        ];
      };

      templates.android-app = {
        path = ./templates/android-app;
        description = "Android app devShell (SDK 35, emulator, x86_64 system image)";
      };
    };
}
