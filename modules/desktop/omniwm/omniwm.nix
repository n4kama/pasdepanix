{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.omniwm;
in {
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
  # Trade-off: because this points at the nix store, editing the file no longer
  # live-reloads in OmniWM; you must edit this file and re-run `just switch`.
  # This keeps the module portable as a public flake.

  options.omniwm.autostart = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = ["Mail"];
    example = ["Mail" "Discord"];
    description = ''
      App names (as passed to `open -a`, e.g. "Mail") to launch at login via a
      per-app LaunchAgent. macOS-only: ignored on other platforms.

      Defaults to Mail. To disable, set `omniwm.autostart = [];`; to change it,
      assign your own list. Which *workspace* an app lands on is separate and
      declared in settings.toml via an OmniWM appRule (`assignToWorkspace =
      "<name>"`) — see the `com.apple.mail` rule (workspace "4"). Pair an entry
      here with a matching appRule to get "open at boot, on that workspace".
    '';
  };

  config = {
    home.file.".config/omniwm/settings.toml" = {
      source = ./settings.toml;
      force = true;
    };

    # OmniWM ships no built-in "start at login" (no SMAppService in the binary), so
    # start it — and any `autostart` apps — from home-manager LaunchAgents instead
    # of stateful macOS login items: declarative, removed cleanly when disabled.
    # `/usr/bin/open` launches once and exits; no KeepAlive so quitting stays quit.
    # Switch to the raw binary + KeepAlive = true if you want crash-restart.
    launchd.agents = lib.mkMerge [
      {
        omniwm = {
          enable = true;
          config = {
            ProgramArguments = ["/usr/bin/open" "-a" "OmniWM"];
            RunAtLoad = true;
          };
        };
      }
      # Autostart apps (macOS-only). One `open -a <App>` agent each; placement on
      # a workspace comes from the app's settings.toml appRule, not from here.
      (lib.mkIf pkgs.stdenv.isDarwin (lib.listToAttrs (map (app: {
          name = "omniwm-open-${lib.toLower (lib.replaceStrings [" "] ["-"] app)}";
          value = {
            enable = true;
            config = {
              ProgramArguments = ["/usr/bin/open" "-a" app];
              RunAtLoad = true;
            };
          };
        })
        cfg.autostart)))
    ];
  };
}
