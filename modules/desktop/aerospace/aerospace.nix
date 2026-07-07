{...}: {
  # AeroSpace - Tiling Window Manager for macOS
  # Installed via homebrew in the nix-darwin configuration.
  # ponytail: in-store copy, no live-edit — edit this file and re-run `just switch`.
  home.file.".config/aerospace/aerospace.toml".source = ./aerospace.toml;
}
