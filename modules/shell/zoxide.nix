{ config, lib, ... }:

{
  programs.zoxide = {
    enable = true;
    enableZshIntegration = true;
  };

  home.sessionVariables = {
    _ZO_EXCLUDE_DIRS = "$HOME/.cache/*:$HOME/Library/Caches/*";
    _ZO_RESOLVE_SYMLINKS = "1";
    _ZO_DATA_DIR = "$HOME/.local/share";
  };
}
