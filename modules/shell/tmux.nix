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

      # Set prefix
      unbind C-b
      set -g prefix C-Space
      bind C-space send-prefix

      # Open panes in the current directory
      bind v split-window -v -c "#{pane_current_path}"
      bind h split-window -h -c "#{pane_current_path}"

      # Allows proper handling of key combinations in tmux
      set-option -g extended-keys on

      # Drive the outer terminal (Ghostty) title from the active pane, so the
      # Hyprland window title / caelestia bar shows the dir instead of "t".
      set -g set-titles on
      set -g set-titles-string "#{s|$HOME|~|:pane_current_path}"
    '';

    plugins = with pkgs.tmuxPlugins; [
      {
        # Options must be set BEFORE catppuccin.tmux runs, or it bakes
        # window-status-format from the mocha/#T defaults first.
        # (home-manager emits per-plugin extraConfig ahead of the run-shell.)
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor "frappe"

          # Window label shows the directory ($HOME shortened to ~), not the process
          set -g @catppuccin_window_text " #{s|$HOME|~|:pane_current_path}"
          set -g @catppuccin_window_current_text " #{s|$HOME|~|:pane_current_path}"
        '';
      }
      sensible
      vim-tmux-navigator
      resurrect
      {
        # This is needed to have tmux session auto-restore when launching tmux.
        # Options must be set BEFORE continuum.tmux runs, or auto-restore reads
        # @continuum-restore as its default 'off' at server start and no-ops.
        # (home-manager emits per-plugin extraConfig ahead of the run-shell.)
        plugin = continuum;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '2'
        '';
      }
    ];
  };
}
