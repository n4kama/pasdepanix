{...}: {
  # Public home-manager modules: tool configurations with no secrets and no
  # personal identity. Imported by the private PaNix config, and usable
  # standalone by anyone.
  imports = [
    # Shell
    ./shell/zsh.nix
    ./shell/tmux.nix
    ./shell/herdr.nix
    ./shell/zoxide.nix
    # Terminal
    ./terminals/ghostty.nix
    # GnuPG agent (pinentry only; no keys)
    ./gpg.nix
    # Editor
    ./editors/neovim
    # Desktop
    ./desktop/omniwm/omniwm.nix
    # Tools
    ./tools/tstream/tstream.nix
    ./tools/calendar-mcp/calendar-mcp.nix
    # Media
    ./media/mpv.nix
  ];
}
