{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.tmux;
in {
  # Which palette the status line draws from. Kept as an option rather than a
  # platform check: the real question is "does something else own my terminal
  # palette", not "am I on Linux".
  options.tmux.theme = lib.mkOption {
    type = lib.types.enum ["catppuccin" "terminal"];
    default = "catppuccin";
    example = "terminal";
    description = ''
      "catppuccin" loads the catppuccin plugin (mocha), which paints the
      status line with fixed hex colours.

      "terminal" drops the plugin and styles the status line from the ANSI
      slots (colour0-15) plus `default`, so it follows whatever palette the
      terminal is set to. Intended for hosts running caelestia, which rewrites
      ANSI 0-15 and fg/bg via OSC on every scheme change — the status line then
      tracks the bar live, with no tmux reload.
    '';
  };

  config.programs.tmux = {
    enable = true;

    extraConfig =
      ''
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
    ''
      + lib.optionalString (cfg.theme == "terminal") ''
        # ANSI slots only — no hex — so a caelestia scheme change repaints this
        # along with everything else in the terminal. `default` keeps the
        # terminal's own background, so the bar sits flush with the pane.
        # colour13 is the nearest ANSI slot to caelestia's primary; swap to
        # colour4 if you'd rather have a blue accent.
        set -g status-style "bg=default,fg=colour7"
        set -g status-left "#[fg=colour13,bold] #S "
        set -g status-right "#[fg=colour8] #{s|$HOME|~|:pane_current_path} "
        set -g window-status-format " #{?automatic-rename,#{s|$HOME|~|:pane_current_path},#W} "
        set -g window-status-current-format "#[fg=colour13,bold] #{?automatic-rename,#{s|$HOME|~|:pane_current_path},#W} "
        set -g pane-border-style "fg=colour8"
        set -g pane-active-border-style "fg=colour13"
        set -g message-style "bg=default,fg=colour13"
      '';

    plugins = with pkgs.tmuxPlugins;
      lib.optional (cfg.theme == "catppuccin") {
        # Options must be set BEFORE catppuccin.tmux runs, or it bakes
        # window-status-format from the mocha/#T defaults first.
        # (home-manager emits per-plugin extraConfig ahead of the run-shell.)
        plugin = catppuccin;
        extraConfig = ''
          set -g @catppuccin_flavor "mocha"

          # Window label shows the directory ($HOME shortened to ~), not the
          # process — unless renamed by hand (prefix ,), which turns
          # automatic-rename off for that window and pins the name.
          set -g @catppuccin_window_text " #{?automatic-rename,#{s|$HOME|~|:pane_current_path},#W}"
          set -g @catppuccin_window_current_text " #{?automatic-rename,#{s|$HOME|~|:pane_current_path},#W}"
        '';
      }
      ++ [
      sensible
      vim-tmux-navigator
      resurrect
      {
        # Continuum keeps saving every 2 min, but restoring is manual (the 'tt'
        # alias) so plain 't' gives a clean session instead of the old layout.
        plugin = continuum;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @continuum-restore 'off'
          set -g @continuum-save-interval '2'
        '';
      }
    ];
  };
}
