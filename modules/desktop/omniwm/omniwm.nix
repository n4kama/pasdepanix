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
  # (write-temp then rename) on GUI changes and on schema migration between
  # releases. The repo is still the source of truth — see the activation block
  # below for the exact semantics.

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
    # settings.toml is installed as a *writable copy*, NOT a nix-store symlink.
    #
    # Semantics — the repo still wins on every switch: each activation
    # overwrites ~/.config/omniwm/settings.toml with the version from this
    # repo. What OmniWM writes in between (GUI edits, schema migrations)
    # persists only until the next switch, then gets reverted.
    #
    # => To make a lasting change: let OmniWM write it, then copy the result
    #    back into ./settings.toml and re-apply. After an OmniWM release with a
    #    schema bump, re-sync the migrated file the same way — it survives on
    #    disk now, so nothing breaks while you get to it.
    #
    # `rm -f` before `install`: install follows an existing symlink and would
    # otherwise try to write through the old store symlink, which is read-only.
    home.activation.omniwmSettings = lib.hm.dag.entryAfter ["writeBoundary"] ''
      run mkdir -p ${lib.escapeShellArg "${config.home.homeDirectory}/.config/omniwm"}
      run rm -f ${lib.escapeShellArg "${config.home.homeDirectory}/.config/omniwm/settings.toml"}
      run install -m 0644 ${./settings.toml} ${lib.escapeShellArg "${config.home.homeDirectory}/.config/omniwm/settings.toml"}
    '';

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
      (lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (lib.listToAttrs (map (app: {
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
