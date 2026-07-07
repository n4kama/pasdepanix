{ inputs, ... }:
{
  imports = [
    inputs.nixvim.homeModules.nixvim
    ./keymaps.nix
    ./options.nix

    ./plugins/alpha.nix
    ./plugins/barbecue.nix
    ./plugins/codecompanion.nix
    ./plugins/lsp.nix
    ./plugins/lualine.nix
    ./plugins/neo-tree.nix
    ./plugins/persistence.nix
    ./plugins/telescope.nix
    ./plugins/tmux-navigator.nix
    ./plugins/treesitter.nix
    ./plugins/which-key.nix
  ];

  programs.nixvim = {
    enable = true;
    defaultEditor = true;

    viAlias = true;
    vimAlias = true;

    colorschemes.catppuccin.enable = true;
    colorschemes.catppuccin.settings.flavour = "frappe";

    # Required by other plugins (telescope, neo-tree, alpha, ...)
    plugins.web-devicons.enable = true;
  };
}
