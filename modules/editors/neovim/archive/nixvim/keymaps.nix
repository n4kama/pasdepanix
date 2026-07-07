{
  programs.nixvim = {
    globals.mapleader = " ";

    # Not using [`keymaps` native nixvim option](https://nix-community.github.io/nixvim/keymaps/index.html)
    # Easier to maintain with non-nixos configurations
    extraConfigLua = ''
      -- Explorer preview
      vim.keymap.set("n", "<leader>pv", vim.cmd.Ex)

      -- Keep cursor in the middle when doing half page jumps
      vim.keymap.set("n", "<C-d>", "<C-d>zz")
      vim.keymap.set("n", "<C-u>", "<C-u>zz")

      -- Keep search terms in the middle
      vim.keymap.set("n", "n", "nzzzv")
      vim.keymap.set("n", "N", "Nzzzv")

      -- Move line above/below
      vim.keymap.set("v", "J", ":m '>+1<CR>gv=gv")
      vim.keymap.set("v", "K", ":m '<-2<CR>gv=gv")
    '';
  };
}
