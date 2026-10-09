{ lib, pkgs, ... }:
let
  # PCIe root port the GTX 1080 sits behind. Its ACPI power resource (LNXPOWER:00)
  # is what actually cuts power to the card once the port runtime-suspends to D3cold.
  rootPort = "00:01.0";
  gpu = "01:00.0";
  gpuAudio = "01:00.1";
in
{
  # Extra boot entry that leaves the GPU unpowered. The normal entry is unchanged and
  # stays the default.
  #
  # The proprietary driver can't power the card down on Pascal (runtime D3 is Turing+),
  # and there's no Optimus/iGPU, so the only route is: no GPU driver, no firmware
  # framebuffer, then let the PCI core suspend the root port. With no driver bound the
  # GPU itself stays in D0, and the port taking D3cold removes its power.
  #
  # Cost: no display output after the kernel starts (systemd-boot still shows, since
  # firmware powers the GPU on every boot), no HDMI/DP, no GPU temperature.
  #
  # Try it once without changing the default (falls back to normal on the next reboot):
  #   sudo bootctl set-oneshot "$(bootctl list --json=short | jq -r '.[] | select(.id | endswith("gpu-off.conf")) | .id' | sort -V | tail -1)"
  #   sudo reboot
  # Then check it's really off (temps.log also records the slot state as gpu=[...]):
  #   cat /sys/bus/acpi/devices/LNXPOWER:00/resource_in_use       # 0
  #   cat /sys/bus/pci/devices/0000:${rootPort}/firmware_node/real_power_state  # D3cold
  specialisation.gpu-off.configuration = {
    system.nixos.tags = [ "gpu-off" ];

    # Drop the nvidia driver set up in power.nix, and stop nouveau taking its place.
    services.xserver.videoDrivers = lib.mkForce [ ];
    hardware.nvidia.nvidiaPersistenced = lib.mkForce false;
    boot.blacklistedKernelModules = [ "nouveau" ];
    # blacklist only stops alias autoloading; also refuse explicit `modprobe nouveau`.
    boot.extraModprobeConfig = ''
      install nouveau ${pkgs.coreutils}/bin/false
    '';

    # simpledrm/efifb would keep using the card's framebuffer and hold it in D0.
    boot.kernelParams = [ "initcall_blacklist=sysfb_init" ];

    # The HDMI audio function is bound to snd_hda_intel (shared with onboard audio, so
    # it can't be blacklisted) and would keep the port awake; remove it from the bus.
    services.udev.extraRules = ''
      ACTION=="add", SUBSYSTEM=="pci", KERNEL=="0000:${gpuAudio}", ATTR{remove}="1"
    '';

    # TLP pins PCI runtime PM to "on" while on AC; allow it just for the GPU and its port.
    services.tlp.settings.RUNTIME_PM_ENABLE = "${rootPort} ${gpu}";
  };
}
