# rognix

A disposable NixOS box on an ASUS ROG Zephyrus GX501. It runs Claude Code Remote Control, so you can drive it from the Claude phone app. Claude has full sudo, so **the whole machine is the sandbox**: keep nothing personal on it, and keep it on an isolated network. The full plan and its reasoning are in [docs/PLAN.md](docs/PLAN.md).

## Before wiping
1. Back up anything personal from the old install.
2. Put the laptop on the router's **guest Wi-Fi or an isolated VLAN** (client isolation on).
3. Revoke the GitHub PAT used on the old install.
4. Write the NixOS 26.05 minimal ISO to a USB stick.

## Install (from the ISO)
The old EFI partition is only 122 MB, too small for NixOS generations. This layout recreates it at 1 GB. **This erases the disk.**

```sh
sudo -i
nmcli device wifi connect "<guest-ssid>" password "<pw>"   # or use nmtui

DISK=/dev/nvme0n1
parted $DISK -- mklabel gpt
parted $DISK -- mkpart ESP fat32 1MiB 1GiB
parted $DISK -- set 1 esp on
parted $DISK -- mkpart root ext4 1GiB -16GiB
parted $DISK -- mkpart swap linux-swap -16GiB 100%
mkfs.fat -F 32 -n BOOT ${DISK}p1
mkfs.ext4 -L nixos ${DISK}p2
mkswap -L swap ${DISK}p3
mount /dev/disk/by-label/nixos /mnt
mkdir -p /mnt/boot && mount -o umask=077 /dev/disk/by-label/BOOT /mnt/boot
swapon /dev/disk/by-label/swap

nixos-generate-config --root /mnt
nix-shell -p git gh
gh auth login                       # new fine-grained PAT: rognix (+ app repos), Contents read/write
gh repo clone td0s/rognix /mnt/etc/rognix
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/rognix/hosts/rognix/
cd /mnt/etc/rognix
git add -A
nix --extra-experimental-features 'nix-command flakes' flake check
nixos-install --flake .#rognix      # sets the root password at the end
nixos-enter --root /mnt -c 'passwd claude'
reboot
```

## First boot
Log in as `claude` on the console:
```sh
sudo mv /etc/rognix ~/rognix && sudo chown -R claude:users ~/rognix
cd ~/rognix
git config user.name td0s
git config user.email 574581+td0s@users.noreply.github.com
git commit -am "rognix: hardware-configuration + flake.lock" && git push   # this one goes to main
gh auth login                         # same scoped PAT
curl -fsSL https://claude.ai/install.sh | bash
claude                                # run /login, then exit
sudo tailscale up
sudo systemctl start claude-remote-control
```
Open the Claude app on your phone, go to Code, and the **rognix** environment should be listed. Start new sessions from there.

Useful commands:
- Attach to the server: `sudo -iu claude tmux attach -t rc`
- Check temperatures: `tail /var/log/temps.log`
- Roll back a bad rebuild: `sudo nixos-rebuild switch --rollback`, or pick an older generation in the boot menu.

## Workflow rules
- Claude changes the system by editing `~/rognix` and running `sudo nixos-rebuild switch --flake ~/rognix#rognix`. It pushes those changes to **branches only**.
- You review and merge to `main`. Reinstalls always come from `main`.
- Start an Android project with `nix flake init -t ~/rognix#android-app`, then `nix develop`.

## Heat
The GX501 opens a vent flap on its underside only when the lid is open. Run a 20-minute build with the emulator going, lid closed, and check `/var/log/temps.log`. If CPU temperatures stay above about 85 °C, run it with the lid open, or closed and stood upright.
