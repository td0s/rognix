{ ... }:
{
  # Out-of-band access when Remote Control is down. Run `sudo tailscale up` once after install.
  services.tailscale.enable = true;

  services.openssh = {
    enable = true;
    openFirewall = false; # reachable only via tailscale0
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
      PermitRootLogin = "no";
    };
  };

  # Root can disable this, so real LAN isolation must come from the router (guest network/VLAN).
  networking.firewall = {
    enable = true;
    trustedInterfaces = [ "tailscale0" ];
  };
}
