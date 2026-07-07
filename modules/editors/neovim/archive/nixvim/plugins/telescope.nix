{ pkgs, ... }:
{
  programs.nixvim = {
    plugins.telescope.enable = true;

    extraPackages = with pkgs; [
      # Necessary for 'live_grep' and 'grep_string'
      # See https://github.com/nvim-telescope/telescope.nvim?tab=readme-ov-file#suggested-dependencies
      ripgrep
      fd
    ];

    # Not using [`plugins.telescope.keymaps`](https://nix-community.github.io/nixvim/plugins/telescope/keymaps/index.html)
    # Easier to maintain with non-nixos configurations
    extraConfigLua = ''
      -- Define locals
      local builtin = require('telescope.builtin')
      local actions = require('telescope.actions')

      -- Define functions
      clever_find_files = function()
        local path = vim.fn.expand("%:p:h")
        local git_dir = vim.fn.finddir(".git", path .. ";")
        if #git_dir > 0 then
          builtin.git_files()
        else
          builtin.find_files()
        end
      end

      -- Define keymaps
      vim.keymap.set('n', '<leader>f', clever_find_files, {desc="Clever search git/files"})
      vim.keymap.set('n', '<leader>o', builtin.buffers, {desc="List buffers"})
      vim.keymap.set('n', '<leader>p', builtin.lsp_document_symbols, {desc="List document symbols"})
      vim.keymap.set('n', '<leader>sb', builtin.buffers, {desc="List buffers"})
      vim.keymap.set('n', '<leader>sB', builtin.git_branches, {desc="Search git branch"})
      vim.keymap.set('n', '<leader>sc', builtin.git_commits, {desc="Search git commit"})
      vim.keymap.set('n', '<leader>sC', builtin.commands, {desc="Search command"})
      vim.keymap.set('n', '<leader>sf', builtin.find_files, {desc="Search file"})
      vim.keymap.set('n', '<leader>sg', builtin.git_files, {desc="Search file in a git repository"})
      vim.keymap.set('n', '<leader>sh', builtin.help_tags, {desc="Search help tag"})
      vim.keymap.set('n', '<leader>sk', builtin.keymaps, {desc="Search vim keymap"})
      vim.keymap.set('n', '<leader>sr', builtin.oldfiles, {desc="Search file opened recently (even outside project)"})
      vim.keymap.set('n', '<leader>sS', builtin.git_status, {desc="Search git status"})
      vim.keymap.set('n', '<leader>st', builtin.live_grep, {desc="Search text (grep)"})
      vim.keymap.set('n', '<leader>sT', builtin.grep_string, {desc="Search text under cursor (grep)"})

      -- Configure telescope
      require('telescope').setup({
        defaults = {
          mappings = {
            i = {
              ["<esc>"] = actions.close,
            },
          },
        },
        pickers = {
          buffers = {
            mappings = {
              i = {
                ["<c-d>"] = actions.delete_buffer,
              },
              n = {
                ["<c-d>"] = actions.delete_buffer,
              },
            },
          },
        },
      })
    '';
  };
}
