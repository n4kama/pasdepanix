{ config, pkgs, lib, ... }:

{
  programs.ghostty = {
    enable = true;
    # Skip installation on macOS (handled by my homebrew host config)
    package = if pkgs.stdenv.hostPlatform.isDarwin then null else pkgs.ghostty;

    settings = {
      # Increased font size to fit my monitor
      font-size = 18;

      # Global terminal hotkeys, macOS only: `cmd` is Super on Linux, where
      # Super+Enter is usually already the WM's own terminal binding.
      # Both override a Ghostty default (toggle_fullscreen, toggle_split_zoom).
      # `global:` fires only while Ghostty is already running.
      keybind = lib.optionals pkgs.stdenv.hostPlatform.isDarwin [
        "global:cmd+enter=new_window"
        "global:cmd+shift+enter=toggle_quick_terminal"
      ];
    };
  };
}
