# rognix: environment notes for Claude

You are running on **rognix**, a disposable NixOS laptop (ASUS GX501, i7-7700HQ, 16 GB RAM, GTX 1080 Mobile) used for Android development. The owner drives you from the Claude phone app.

## System
- The OS is **NixOS**: there's no apt, dnf or pacman. You have passwordless `sudo`.
- **Per-project tooling:** give each project a `flake.nix` devShell and use `nix develop`. For one-off tools, use `nix shell nixpkgs#<pkg>`. Don't install tools globally just for one project.
- **System changes** (services, system packages, kernel or hardware settings):
  1. Edit the flake in `~/rognix`.
  2. Run `sudo nixos-rebuild switch --flake ~/rognix#rognix`.
  3. Commit, then **push to a branch, never to `main`**. The owner reviews and merges.
  4. If a rebuild breaks the system, run `sudo nixos-rebuild switch --rollback`.
- Prebuilt dynamic binaries run through nix-ld.

## Android
- Start a new app from the template: `nix flake init -t ~/rognix#android-app`, then `nix develop`.
- Create an emulator: `avdmanager create avd -n dev -k "system-images;android-35;google_apis;x86_64"`.
- Run the emulator headless (there's no display): `emulator -avd dev -no-window -gpu swiftshader_indirect -no-audio &`, then wait with `adb wait-for-device`.
- Physical devices only connect over USB. The laptop sits on an isolated network, so wireless adb won't work.

## Constraints
- **Heat:** builds and the emulator heat this laptop, often with the lid shut. Stop the emulator when you're done (`adb emu kill`). Avoid leaving long-running heavy jobs unattended. Temperatures are logged to `/var/log/temps.log`.
- **Secrets:** don't store secrets on this machine beyond the scoped GitHub token. App signing keys and store credentials live elsewhere.
