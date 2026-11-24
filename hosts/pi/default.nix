{ lib, ... }:

let
  # ---- Site settings ----
  # Published by the fork's docker-ghcr.yml (amd64 + arm64). The workflow names
  # the image music-assistant-skill, not after the repo.
  image = "ghcr.io/td0s/music-assistant-skill:0.0.39-beta";
  skillHost = "skill.tdos.co.uk";
  maStreamHost = "music.tdos.co.uk"; # proxies to Music Assistant's stream port (8097)
  maIp = "192.168.1.25";
  proxyIp = "100.100.112.107"; # reverse proxy for the Alexa skill (Tailscale address)
  # -------------------------------------------------------
in
{
  networking.hostName = "pi";
  system.stateVersion = "26.05";

  # Boot the kernel straight from the Pi firmware, skipping U-Boot.
  # If the Pi won't boot, change this to "uboot" and rebuild the image.
  boot.loader.raspberry-pi.bootloader = "kernel";

  # The Pi-Lite needs the good UART (PL011, /dev/ttyAMA0) on GPIO 14/15,
  # which Bluetooth uses by default on a Pi 3.
  # (nixos-raspberrypi has no Bluetooth module for the Pi 3, so there is no
  # hardware.raspberry-pi.bluetooth option to turn off; disable-bt does it.)
  hardware.raspberry-pi.config.all.dt-overlays.disable-bt = {
    enable = true;
    params = { };
  };
  # Drops console=serial0: a console on the UART would talk over the Pi-Lite.
  boot.kernelParams = lib.mkForce [ "console=tty1" ];

  services.pilite-eq = {
    enable = true;
    extraArgs = [ ];
  };

  # 1 GB RAM: compressed RAM swap first, then a swapfile.
  zramSwap.enable = true;
  swapDevices = [
    {
      device = "/var/swapfile";
      size = 2048;
    }
  ];

  documentation.enable = false;
  services.journald.extraConfig = "SystemMaxUse=100M";

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };
  # tobias must be trusted to receive unsigned builds from rognix.
  nix.settings.trusted-users = [
    "root"
    "tobias"
  ];

  users.users.tobias = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    openssh.authorizedKeys.keys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIOmICF//KAuQ+UXOzcSyMDhSi0J+gM++JEmdXlNExTzB" ];
  };
  security.sudo.wheelNeedsPassword = false;

  services.openssh = {
    enable = true;
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };

  # Joins the tailnet on first boot with the key copied to the Pi by hand.
  services.tailscale = {
    enable = true;
    authKeyFile = "/var/lib/tailscale-authkey";
  };
  networking.firewall.trustedInterfaces = [ "tailscale0" ];

  # Music Assistant Alexa skill.
  virtualisation.podman.enable = true;
  virtualisation.oci-containers.backend = "podman";
  virtualisation.oci-containers.containers.ma-alexa = {
    inherit image;
    ports = [ "5000:5000" ];
    volumes = [ "/var/lib/ma-alexa/ask:/root/.ask" ];
    environment = {
      SKILL_HOSTNAME = skillHost;
      MA_HOSTNAME = maStreamHost;
      MA_API_URL = "http://${maIp}:8095";
      LOCALE = "en-GB";
      TZ = "Europe/London";
    };
    # APP_USERNAME, APP_PASSWORD, MA_API_TOKEN: created on the Pi by hand,
    # never in this repo or the Nix store.
    environmentFiles = [ "/var/lib/ma-alexa/secrets.env" ];
  };
  systemd.tmpfiles.rules = [ "d /var/lib/ma-alexa/ask 0700 root root -" ];

  networking.nftables.enable = true;
  networking.firewall.extraInputRules = ''
    ip saddr ${proxyIp} tcp dport 5000 accept
  '';
}
