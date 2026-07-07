{
  programs.nixvim = {    
    extraConfigLua = ''
      vim.opt.backup = false               -- creates a backup file
      vim.opt.clipboard = "unnamedplus"    -- allows neovim to access the system clipboard
      vim.opt.cmdheight = 1                -- more space in the neovim command line for displaying messages
      vim.opt.conceallevel = 0             -- so that `` is visible in markdown files
      vim.opt.fileencoding = "utf-8"       -- the encoding written to a file
      vim.opt.hlsearch = true              -- highlight all matches on previous search pattern
      vim.opt.incsearch = true             -- highlight all matches on previous search pattern
      vim.opt.ignorecase = true            -- ignore case in search patterns
      vim.opt.mouse = "a"                  -- allow the mouse to be used in neovim
      vim.opt.pumheight = 10               -- pop up menu height
      vim.opt.showmode = true              -- disables the -- INSERT -- line
      vim.opt.showtabline = 2              -- always show tabs
      vim.opt.smartindent = true           -- make indenting smarter again
      vim.opt.splitbelow = true            -- force all horizontal splits to go below current window
      vim.opt.splitright = true            -- force all vertical splits to go to the right of current window
      vim.opt.swapfile = false             -- creates a swapfile
      vim.opt.termguicolors = true         -- set term gui colors (most terminals support this)
      vim.opt.timeoutlen = 100             -- time to wait for a mapped sequence to complete (in milliseconds)
      --vim.opt.undodir = os.getenv("HOME") .. "/.vim/undodir",  -- List of directory names for undo files
      vim.opt.undofile = true              -- enable persistent undo
      vim.opt.updatetime = 50              -- faster completion (4000ms default)
      vim.opt.writebackup = true           -- if a file is being edited by another program (or was written to file while editing with another program)  it is not allowed to be edited
      vim.opt.expandtab = true             -- convert tabs to spaces
      vim.opt.shiftwidth = 2               -- the number of spaces inserted for each indentation
      vim.opt.tabstop = 2                  -- insert 2 spaces for a tab
      vim.opt.cursorline = true            -- highlight the current line
      vim.opt.cursorcolumn = false         -- highlight the current line
      --vim.opt.colorcolumn = "80" 
      vim.opt.number = true                -- set numbered lines
      vim.opt.relativenumber = true        -- set relative numbered lines
      vim.opt.numberwidth = 2              -- set number column width to 2 {default 4}

      vim.opt.signcolumn = "yes"           -- always show the sign column, otherwise it would shift the text each time
      vim.opt.wrap = true                  -- display lines as one long line
      vim.opt.linebreak = true             -- companion to wrap, don't split words
      vim.opt.scrolloff = 10               -- minimal number of screen lines to keep above and below the cursor
      --vim.opt.sidescrolloff = 10         -- minimal number of screen columns either side of cursor if wrap is `false`
      --vim.opt.guifont = "monospace:h17"  -- the font used in graphical neovim applications
      --vim.opt.whichwrap = "bs<>[]hl"     -- which "horizontal" keys are allowed to travel to prev/next line

      -- remove the '~' symbol from empty lines
      vim.opt.fillchars:append { eob = " " }
    '';
  };
}
