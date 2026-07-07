{
  programs.nixvim.plugins = {
    lsp-format.enable = true;

    lsp = {
      enable = true;

      keymaps = {
        silent = true;
        diagnostic = {
          # Navigate in diagnostics
          "<leader>k" = "goto_prev";
          "<leader>j" = "goto_next";
        };

        lspBuf = {
          gd = "definition";
          gD = "references";
          gt = "type_definition";
          gi = "implementation";
          K = "hover";
          "<F2>" = "rename";
        };
      };

      # Refer to [this table](https://microsoft.github.io/language-server-protocol/implementors/servers/)
      servers = {
        # ansiblels.enable = true;
        gopls.enable = true;
        html.enable = true;
        jsonls.enable = true;
        lua_ls.enable = true;
        marksman.enable = true;
        nil_ls.enable = true;
        pyright.enable = true;
        yamlls.enable = true;
      };
    };
  };
}
