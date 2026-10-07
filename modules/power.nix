{ config, pkgs, ... }:
{
  # Keep running with the lid shut. Note: the GX501's underside air flap only opens
  # with the lid open, so check /var/log/temps.log before relying on lid-closed use.
  services.logind.settings.Login = {
    HandleLidSwitch = "ignore";
    HandleLidSwitchExternalPower = "ignore";
    HandleLidSwitchDocked = "ignore";
  };

  services.thermald.enable = true;

  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "powersave";
      CPU_ENERGY_PERF_POLICY_ON_AC = "balance_power";
      # Turbo off is the biggest heat win; set to 1 if builds are too slow.
      CPU_BOOST_ON_AC = 0;
      # Always plugged in: hold the battery around 80% (asus-wmi supports the stop threshold).
      START_CHARGE_THRESH_BAT0 = 75;
      STOP_CHARGE_THRESH_BAT0 = 80;
    };
  };

  # GTX 1080 Mobile is the only GPU (no Optimus). Pascal support ended with the 580 branch,
  # so the default (595+) driver won't bind to it; the open kernel modules don't support Pascal.
  hardware.graphics.enable = true;
  services.xserver.videoDrivers = [ "nvidia" ];
  hardware.nvidia = {
    package = config.boot.kernelPackages.nvidiaPackages.legacy_580;
    open = false;
    modesetting.enable = true;
    # Keeps the driver initialised while headless so the GPU drops to its idle P8 state.
    nvidiaPersistenced = true;
  };

  systemd.services.temps-log = {
    description = "Append CPU/GPU temperatures to /var/log/temps.log";
    path = [
      pkgs.coreutils
      config.hardware.nvidia.package.bin
    ];
    script = ''
      cpu=$(cat /sys/class/thermal/thermal_zone*/temp | awk '{printf "%d ", $1/1000}')
      gpu=$(nvidia-smi --query-gpu=temperature.gpu,pstate --format=csv,noheader 2>/dev/null || echo n/a)
      echo "$(date -Is) cpu=[$cpu] gpu=[$gpu]" >> /var/log/temps.log
    '';
    serviceConfig.Type = "oneshot";
  };
  systemd.timers.temps-log = {
    wantedBy = [ "timers.target" ];
    timerConfig.OnCalendar = "*:0/5";
  };
}
