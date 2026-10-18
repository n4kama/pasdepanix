{
  description = "pasdepanix — public home-manager modules (tool configs, no secrets)";

  outputs = {self, ...}: {
    # A single aggregate module, plus each module individually so consumers can
    # cherry-pick. No secrets, no identity, no host-specific values.
    homeModules = {
      default = import ./modules;

      zsh = ./modules/shell/zsh.nix;
      tmux = ./modules/shell/tmux.nix;
      herdr = ./modules/shell/herdr.nix;
      zoxide = ./modules/shell/zoxide.nix;
      ghostty = ./modules/terminals/ghostty.nix;
      gpg = ./modules/gpg.nix;
      neovim = ./modules/editors/neovim;
      omniwm = ./modules/desktop/omniwm/omniwm.nix;
      hyprland = ./modules/desktop/hyprland.nix;
      caelestia = ./modules/desktop/caelestia.nix;
      tstream = ./modules/tools/tstream/tstream.nix;
      calendar-mcp = ./modules/tools/calendar-mcp/calendar-mcp.nix;
      mpv = ./modules/media/mpv.nix;
    };
  };
}
