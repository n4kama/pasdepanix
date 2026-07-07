{...}: {
  # Public home-manager modules: tool configurations with no secrets and no
  # personal identity. Imported by the private PaNix config, and usable
  # standalone by anyone.
  imports = [
    # Shell
    ./shell/zsh.nix
    ./shell/tmux.nix
    ./shell/zoxide.nix
    # Terminal
    ./terminals/ghostty.nix
    # GnuPG agent (pinentry only; no keys)
    ./gpg.nix
    # Editor
    ./editors/neovim
    # Desktop
    ./desktop/omniwm/omniwm.nix
    # ./desktop/aerospace/aerospace.nix   # archived
    # ./desktop/sketchybar/sketchybar.nix # archived — no permanent status bar for now
  ];
}
