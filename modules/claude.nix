{ pkgs, ... }:
let
  home = "/home/claude";
in
{
  environment.systemPackages = with pkgs; [
    git
    gh
    tmux
    curl
    wget
    jq
    ripgrep
    nodejs
    jdk17
    android-tools
  ];

  systemd.tmpfiles.rules = [
    "d ${home}/projects 0755 claude users -"
    "d ${home}/.claude 0700 claude users -"
    # Copied once, so Claude can edit its own copy afterwards.
    "C ${home}/.claude/CLAUDE.md 0644 claude users - ${../CLAUDE.md}"
  ];

  # Remote Control server, controllable from the Claude phone app. Runs inside tmux so
  # you can attach over SSH with `sudo -iu claude tmux attach -t rc`. When claude exits,
  # the tmux server exits and systemd restarts it.
  systemd.services.claude-remote-control = {
    description = "Claude Code Remote Control server";
    wantedBy = [ "multi-user.target" ];
    wants = [ "network-online.target" ];
    after = [ "network-online.target" ];
    # Waits until Claude Code is installed (native installer, see README).
    unitConfig.ConditionPathExists = "${home}/.local/bin/claude";
    serviceConfig = {
      User = "claude";
      WorkingDirectory = "${home}/projects";
      Type = "forking";
      # A login shell gives the full PATH, including /run/wrappers/bin (sudo) and ~/.local/bin.
      ExecStart = ''${pkgs.tmux}/bin/tmux new-session -d -s rc "${pkgs.bashInteractive}/bin/bash -lc 'exec claude remote-control --name rognix --spawn same-dir --permission-mode auto'"'';
      ExecStop = "${pkgs.tmux}/bin/tmux kill-session -t rc";
      Restart = "always";
      RestartSec = 10;
    };
  };
}
