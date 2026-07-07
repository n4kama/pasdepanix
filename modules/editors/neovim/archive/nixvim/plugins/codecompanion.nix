{
  # Test comment
  programs.nixvim = {
    plugins.codecompanion = {
      enable = true;
      settings = {
        adapters = {
          http = {
            ollama_chat = {
              __raw = ''
                function()
                  return require("codecompanion.adapters").extend("ollama", {
                    schema = {
                      model = {
                        default = "qwen2.5-coder:32b",
                      },
                    },
                  })
                end
              '';
            };
            ollama_inline = {
              __raw = ''
                function()
                  return require("codecompanion.adapters").extend("ollama", {
                    schema = {
                      model = {
                        default = "qwen2.5-coder:1.5b",
                      },
                    },
                  })
                end
              '';
            };
          };
        };
        strategies = {
          chat.adapter = "ollama_chat";
          inline.adapter = "ollama_inline";
          agent.adapter = "ollama_chat";
        };
      };
    };

    keymaps = [
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>a";
        action = "<cmd>CodeCompanionActions<cr>";
        options = {
          desc = "AI Actions (Agent)";
          noremap = true;
          silent = true;
        };
      }
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>ac";
        action = "<cmd>CodeCompanionChat Toggle<cr>";
        options = {
          desc = "AI Chat";
          noremap = true;
          silent = true;
        };
      }
      {
        mode = "v";
        key = "ga";
        action = "<cmd>CodeCompanionChat Add<cr>";
        options = {
          desc = "Add to AI Chat";
          noremap = true;
          silent = true;
        };
      }
      {
        mode = [
          "n"
          "v"
        ];
        key = "<leader>ai";
        action = "<cmd>CodeCompanion<cr>";
        options = {
          desc = "AI Inline / Command";
          noremap = true;
          silent = true;
        };
      }
    ];
  };
}
