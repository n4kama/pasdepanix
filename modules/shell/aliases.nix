{
  pkgs,
  ...
}:
{
  c = "clear";
  cl = "claude --continue";
  d = "cd ~/Downloads";
  dcp = "docker compose";
  gl = "git log";
  gp = "git push";
  gpr = "git pull --rebase";
  gs = "git status";
  l = "lazygit";
  oc = "opencode --continue";
  # Attach to whatever is running; only make a fresh 'main' if nothing is.
  t = "tmux attach || tmux new -s main";
  # Bring back the last continuum/resurrect save (auto-restore is off).
  tt = "tmux start-server; tmux run-shell ${pkgs.tmuxPlugins.resurrect}/share/tmux-plugins/resurrect/scripts/restore.sh; tmux attach";
  v = "nvim";
  vi = "nvim";
  vim = "nvim";
  vv = "nvim .";
  y = "yazi";
}
// pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
  tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
}
