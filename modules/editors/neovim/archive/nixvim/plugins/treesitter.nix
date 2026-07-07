{
  programs.nixvim.plugins = {
    treesitter = {
      enable = true;

      settings = {
        highlight.enable = true;
        indent.enable = true;
      };
      
      # Highlighting extraConfigLua as lua e.g.
      nixvimInjections = true;
    };
    
    # For home manager
    hmts.enable = true;
  };
}
