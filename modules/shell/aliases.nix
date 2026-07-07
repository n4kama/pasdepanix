{
  pkgs,
  ...
}:
{
  c = "clear";
  cl = "claude --continue";
  dcp = "docker compose";
  gl = "git log";
  gp = "git push";
  gpr = "git pull --rebase";
  gs = "git status";
  l = "lazygit";
  oc = "opencode --continue";
  t = "tmux new-session -A -s main";
  v = "nvim";
  vi = "nvim";
  vim = "nvim";
  vv = "nvim .";
  y = "yazi";
}
// pkgs.lib.optionalAttrs pkgs.stdenv.isDarwin {
  tailscale = "/Applications/Tailscale.app/Contents/MacOS/Tailscale";
}
