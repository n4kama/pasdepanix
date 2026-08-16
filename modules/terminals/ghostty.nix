{ config, pkgs, lib, ... }:

{
  programs.ghostty = {
    enable = true;
    # Skip installation on macOS (handled by my homebrew host config)
    package = if pkgs.stdenv.hostPlatform.isDarwin then null else pkgs.ghostty;

    settings = {
      # Increased font size to fit my monitor
      font-size = 18;
    };
  };
}
