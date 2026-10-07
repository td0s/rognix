# Plan: rebuild the laptop as a NixOS "rognix", controlled from your phone

## Context
You want this laptop to be a disposable machine for Android development that you drive from your phone. Claude has full sudo and you start sessions from the phone app. The whole device plus your network is the security boundary, so nothing personal stays on it. Since the laptop is being wiped anyway, it'll be reinstalled as **NixOS, defined by a flake in a git repo**. That gives:
- **Repeatable setup.** Rebuild from scratch in about 20 minutes with `nixos-install --flake`.
- **Rollback.** If a session breaks the system, pick an earlier generation from the boot menu.
- **Reviewable changes.** Claude changes the system by editing the flake and running `nixos-rebuild`, so every system change is a git diff.

Hardware relevant to the config (from inspecting it):
- i7-7700HQ with VT-x, and `/dev/kvm` works.
- 16 GB of RAM and a 452 GB NVMe.
- A GTX 1080 Mobile that appears to be the only GPU (no Intel VGA device listed, so probably no Optimus).
- The battery supports `charge_control_end_threshold`.

## Repo layout
I'll scaffold this now in `~/claude-projects/rognix` and push it to your private repo **https://github.com/td0s/rognix** (`main`) so it survives the wipe. This plan goes in too, as `docs/PLAN.md`:
```
flake.nix                      # nixosConfigurations.rognix; inputs: nixpkgs (latest stable)
hosts/rognix/
  configuration.nix            # imports modules below
  hardware-configuration.nix   # placeholder; replaced by nixos-generate-config during install
modules/
  base.nix        # flakes on, allowUnfree, nix.gc weekly, boot.loader.systemd-boot (configurationLimit = 10),
                  # NetworkManager, timezone, nix-ld (needed for Gradle's aapt2 and Claude's native binary)
  users.nix       # users.users.claude (wheel, kvm, adbusers), passwordless sudo for wheel, your SSH pubkey
  power.nix       # lid ignore (logind), thermald, cpuFreqGovernor = "powersave", TLP with STOP_CHARGE_THRESH_BAT0 = 80,
                  # proprietary nvidia driver so the dGPU idles in P8, temps logger (systemd timer -> /var/log/temps.log)
  remote.nix      # tailscale; openssh with key auth only, reachable only via tailscale0 (firewall trustedInterfaces)
  claude.nix      # systemd service claude-remote-control (User=claude, Restart=always, after network-online),
                  # runs `tmux new -d -s rc 'claude remote-control --name rognix --spawn worktree --permission-mode auto'`
                  # inside ~/projects; system packages: git, gh, tmux, nodejs, jdk17, android-tools
templates/android-app/flake.nix  # devShell using androidenv.composeAndroidPackages (platform 35, build-tools,
                                 # emulator, x86_64 google_apis image, android_sdk.accept_license = true)
CLAUDE.md                         # describes the box to Claude (see below)
```

`CLAUDE.md` (later copied to `/home/claude/projects/CLAUDE.md`) tells Claude:
- The OS is NixOS, so there's no apt.
- For per-project tooling, use the project's `flake.nix` devShell (`nix develop`), or `nix shell nixpkgs#foo` for one-off tools.
- For system changes, edit `~/rognix`, run `sudo nixos-rebuild switch --flake ~/rognix#rognix`, commit, and push to a branch, never to `main`.
- How to run the emulator headless: `emulator -avd dev -no-window -gpu swiftshader_indirect -no-audio`.

**Choice: Claude Code comes from the native installer**, not the nixpkgs `claude-code` package. Remote Control changes quickly and the nixpkgs package lags behind. nix-ld lets the native binary run. The trade-off is that its version isn't pinned by the flake.

**Supply-chain guard:** Claude pushes system changes only to branches. You merge to `main` from GitHub on your phone, and reinstalls always use `main`. That way a compromised session can't plant config that survives a reinstall.

## Steps
1. **Scaffold and push (me, now, on Slackware).**
   - Write the files above, plus `docs/PLAN.md` (a copy of this plan) and a `README.md` with the install steps from step 4, so you can follow them from the ISO.
   - In `~/claude-projects/rognix`: `git init -b main`, set the repo-local identity (`user.name td0s`, `user.email 574581+td0s@users.noreply.github.com`), add the remote `https://github.com/td0s/rognix.git`, and commit.
   - Nix isn't installed here, so it can't be evaluated yet.
   - **Auth:** use the `GH_TOKEN` that `~/.bashrc` exports. The token isn't printed or written to disk. A one-off inline credential helper reads it from the environment: `bash -c 'source ~/.bashrc; git -c credential.helper= -c credential.helper="!f() { echo username=x-access-token; echo password=\$GH_TOKEN; }; f" push -u origin main'`.
   - Confirm the push worked with `git ls-remote origin` (same helper).
   - **Revoke that PAT before or after the wipe.** The new box gets its own token in step 5.
2. **Back up and clean up (you).** Copy anything personal off the laptop, such as Firefox data, mail, `~/.gnupg` and Documents. Check that `rognix` on GitHub has `docs/PLAN.md` before you wipe.
3. **Network (you).** Put the laptop on the router's guest Wi-Fi or a VLAN with client isolation. Root can undo any local firewall, so this has to happen on the router.
4. **Install (you, from the NixOS minimal ISO on USB):**
   - Partition and mount the disk, then run `nixos-generate-config --root /mnt`.
   - Clone the repo and copy in the generated `hardware-configuration.nix`.
   - Run `nix flake check`, then `nixos-install --flake .#rognix`.
5. **First boot (you, as `claude`):**
   - Install Claude Code with the native installer and run `/login`.
   - Run `gh auth login` with a **fine-grained PAT** limited to the app repos and `rognix` (contents read/write, no admin).
   - Run `tailscale up`.
   - Clone `rognix` to `~/rognix`.
   - Start the service: `sudo systemctl enable --now claude-remote-control`.
6. **Android (Claude can do this itself, from your phone):**
   - Create a project from the template and enter it with `nix develop`.
   - Run `avdmanager create avd -n dev`, then do a test build onto the emulator.
   - For a real phone, use USB adb. Wireless adb won't cross the isolated guest network.

## Verification
- `nix flake check` passes in the installer before `nixos-install`.
- Reboot with the lid closed. The box appears in the Claude phone app within about 2 minutes, and `systemctl status claude-remote-control` shows it active.
- From the phone, spawn two sessions in parallel:
  - In one, have Claude add a package to the flake, rebuild, commit and push to a branch.
  - In the other, build a sample app and install it on the headless emulator (`adb devices` should list `emulator-5554`).
- Roll back: reboot, pick the previous generation, and confirm the package is gone.
- Isolation: from a session, `curl` the router's admin IP and another LAN device; both should fail. `curl https://example.com` should succeed.
- Heat: run a build plus the emulator for 20 minutes with the lid closed, then check `/var/log/temps.log`. If it stays above about 85 °C, run lid-open or upright.
- Recovery drill (optional): wipe and reinstall from `main` to prove the setup is reproducible.
