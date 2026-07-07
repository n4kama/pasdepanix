{
  programs.nixvim = {
    plugins.neo-tree = {
      enable = true;

      settings = {
        close_if_last_window = true;
        window = {
          position = "float";
        };
      };
    };

    keymaps = [
      {
        mode = "n";
        key = "<leader>n";
        action = ":Neotree reveal toggle<CR>";
        options.silent = true;
      }
    ];
  };
}
