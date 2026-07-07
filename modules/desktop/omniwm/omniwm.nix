{...}: {
  # OmniWM - Tiling Window Manager for macOS
  # Installed via homebrew (BarutSRB/tap, cask "omniwm") in the nix-darwin configuration.
  #
  # OmniWM owns settings.toml: it reads it on launch and *rewrites it atomically*
  # (write-temp then rename) whenever you change a setting in its GUI.
  #
  # The repo is the source of truth: settings.toml here is copied into the nix store
  # and symlinked to ~/.config/omniwm/settings.toml. `force = true` makes every
  # `just switch` overwrite whatever OmniWM's GUI wrote — the repo wins.
  #
  # Trade-off (ponytail: in-store, no live-edit): because this points at the nix
  # store, editing the file no longer live-reloads in OmniWM; you must edit this
  # file and re-run `just switch`. This keeps the module portable as a public flake.
  home.file.".config/omniwm/settings.toml" = {
    source = ./settings.toml;
    force = true;
  };
}
