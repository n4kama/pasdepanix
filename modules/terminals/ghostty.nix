{ config, pkgs, lib, ... }:

{
  programs.ghostty = {
    enable = true;
    # Skip installation on macOS (handled by my homebrew host config)
    package = if pkgs.stdenv.hostPlatform.isDarwin then null else pkgs.ghostty;

    settings = {
      # Increased font size to fit my monitor
      font-size = 18;

      # Global terminal hotkey, macOS only: `cmd` is Super on Linux, where
      # Super+Enter is usually already the WM's own terminal binding.
      # Overrides Ghostty's default cmd+enter (toggle_fullscreen), and
      # `global:` fires only while Ghostty is already running.
      # The quick terminal is OmniWM's quake terminal instead, on
      # Shift+Command+Return.
      keybind = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        "global:cmd+enter=new_window"
      ];
    };
  };
}
