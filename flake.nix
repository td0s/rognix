{
  description = "rognix: disposable NixOS box for phone-controlled Claude Code (ASUS ROG Zephyrus GX501)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs, ... }:
    {
      nixosConfigurations.rognix = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        modules = [ ./hosts/rognix/configuration.nix ];
      };

      templates.android-app = {
        path = ./templates/android-app;
        description = "Android app devShell (SDK 35, emulator, x86_64 system image)";
      };
    };
}
