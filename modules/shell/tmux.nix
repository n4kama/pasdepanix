{pkgs, ...}: {
  programs.tmux = {
    enable = true;

    extraConfig = ''
      # Enable mouse
      set -g mouse on

      # Start windows and panes at 1, not 0
      set -g base-index 1
      set -g pane-base-index 1
      set-window-option -g pane-base-index 1
      set-option -g renumber-windows on

      # Configure catppuccin
      set -g @catppuccin_flavour "frappe"

      # Set prefix
      unbind C-b
      set -g prefix C-Space
      bind C-space send-prefix

      # Open panes in the current directory
      bind v split-window -v -c "#{pane_current_path}"
      bind h split-window -h -c "#{pane_current_path}"

      # Allows proper handling of key combinations in tmux
      set-option -g extended-keys on
    '';

    plugins = with pkgs.tmuxPlugins; [
      catppuccin
      sensible
      vim-tmux-navigator
    ];
  };
}
