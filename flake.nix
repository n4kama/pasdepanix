{
  description = "pasdepanix — public home-manager modules (tool configs, no secrets)";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = {self, ...}: {
    # A single aggregate module, plus each module individually so consumers can
    # cherry-pick. No secrets, no identity, no host-specific values.
    homeManagerModules = {
      default = import ./modules;

      zsh = ./modules/shell/zsh.nix;
      tmux = ./modules/shell/tmux.nix;
      zoxide = ./modules/shell/zoxide.nix;
      ghostty = ./modules/terminals/ghostty.nix;
      gpg = ./modules/gpg.nix;
      neovim = ./modules/editors/neovim;
      omniwm = ./modules/desktop/omniwm/omniwm.nix;
      hyprland = ./modules/desktop/hyprland.nix;
      waybar = ./modules/desktop/waybar.nix;
      mako = ./modules/desktop/mako.nix;
      aerospace = ./modules/desktop/aerospace/aerospace.nix;
      sketchybar = ./modules/desktop/sketchybar/sketchybar.nix;
    };
  };
}
