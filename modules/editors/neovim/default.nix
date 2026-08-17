{
  pkgs,
  config,
  ...
}: {
  # LazyVim configuration
  # Prerequisites: https://www.lazyvim.org/
  home.packages = with pkgs; [
    # Runtime tools this neovim config needs, kept here so the module is
    # self-sufficient when imported standalone.

    # Search (telescope / LazyVim)
    ripgrep
    fd

    # LSP
    nixd # Install manually as not available in Mason (as of 2026-03)
    rust-analyzer # Install via nix, not Mason, to avoid a second toolchain
    # Treesitter
    tree-sitter
    # Formatters (conform.nvim)
    alejandra
    nixfmt
    prettier
    prettierd
    ruff
    rustfmt
    stylua

    # Neovim
    neovim
  ];

  # Shell aliases for vi/vim to use neovim
  home.sessionVariables = {
    EDITOR = "nvim";
    VISUAL = "nvim";
  };

  programs.zsh.shellAliases = {
    vi = "nvim";
    vim = "nvim";
  };

  # Symlink to local nvim-config repo for live editing and git workflow
  xdg.configFile."nvim" = {
    source = config.lib.file.mkOutOfStoreSymlink "${config.home.homeDirectory}/dev/nvim-config";
    force = true;
    recursive = true;
  };
}
