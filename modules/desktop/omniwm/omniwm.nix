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

  # OmniWM ships no built-in "start at login" (no SMAppService in the binary), so
  # start it from a home-manager LaunchAgent instead of a stateful macOS login item
  # declarative and removed cleanly when this module is disabled.
  # `/usr/bin/open` launches once and exits; no KeepAlive so quitting OmniWM stays
  # quit. Switch to the raw binary + KeepAlive = true if you want crash-restart.
  launchd.agents.omniwm = {
    enable = true;
    config = {
      ProgramArguments = ["/usr/bin/open" "-a" "OmniWM"];
      RunAtLoad = true;
    };
  };
}
