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
  # The session named after the current directory, created if needed.
  t = "tmux-session";
}
// pkgs.lib.optionalAttrs pkgs.stdenv.hostPlatform.isDarwin {
  tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
}
