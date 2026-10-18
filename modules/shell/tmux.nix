{
  pkgs,
  lib,
  config,
  ...
}: let
  cfg = config.tmux;

  # Attach to (or, inside tmux, switch to) the session for a directory,
  # creating it there first if needed. The session is named after the path,
  # "~/..." under $HOME; ":" becomes "_" because tmux reads it as the
  # session:window separator. Targets end in ":" so a "." in the name is not
  # read as window.pane.
  tmux-session = pkgs.writeShellApplication {
    name = "tmux-session";
    runtimeInputs = [pkgs.tmux];
    excludeShellChecks = ["SC2088"];
    text = ''
      dir="$(cd -- "''${1:-$PWD}" && pwd)"
      case "$dir" in
        "$HOME") name="~" ;;
        "$HOME"/*) name="~/''${dir#"$HOME"/}" ;;
        *) name="$dir" ;;
      esac
      name="''${name//:/_}"

      tmux has-session -t "=$name:" 2>/dev/null || tmux new-session -d -s "$name" -c "$dir"
      if [ -n "''${TMUX:-}" ]; then
        exec tmux switch-client -t "=$name:"
      else
        exec tmux attach-session -t "=$name:"
      fi
    '';
  };

  fzfPopup = "--reverse --no-sort --border=none --info=inline-right";

  # prefix s: switch to another open session, most recently used first,
  # previewing its active pane.
  tmux-pick-session = pkgs.writeShellApplication {
    name = "tmux-pick-session";
    runtimeInputs = [pkgs.tmux pkgs.fzf pkgs.gawk pkgs.coreutils];
    text = ''
      tab=$'\t'
      current="$(tmux display-message -p '#{session_id}')"
      choice="$(
        tmux list-sessions -F "#{session_last_attached}$tab#{session_id}$tab#{session_name}$tab#{session_windows}w" |
          sort -rn |
          awk -F'\t' -v OFS='\t' -v c="$current" '$2 != c { print $2, $3, $4 }' |
          fzf ${fzfPopup} --delimiter='\t' --with-nth=2.. \
            --preview 'tmux capture-pane -ep -t {1}' --preview-window=right,60%
      )" || exit 0
      tmux switch-client -t "''${choice%%"$tab"*}"
    '';
  };

  # prefix o: pick a directory (the current pane's first, then zoxide's
  # frecency list) and switch to its session, creating it if needed.
  tmux-pick-dir = pkgs.writeShellApplication {
    name = "tmux-pick-dir";
    runtimeInputs = [pkgs.zoxide pkgs.fzf pkgs.gawk];
    excludeShellChecks = ["SC2088"];
    text = ''
      choice="$(
        { printf '%s\n' "$PWD"; zoxide query -l; } |
          awk -v h="$HOME" '!seen[$0]++ {
            if ($0 == h) print "~"
            else if (index($0, h "/") == 1) print "~" substr($0, length(h) + 1)
            else print
          }' |
          fzf ${fzfPopup}
      )" || exit 0
      case "$choice" in
        "~") choice="$HOME" ;;
        "~/"*) choice="$HOME/''${choice#"~/"}" ;;
      esac
      exec ${lib.getExe tmux-session} "$choice"
    '';
  };

  # Claude Code hook target: records the conversation state as the pane
  # option @claude (working / waiting / idle) and its session id as
  # @claude_session. Does nothing outside tmux.
  tmux-claude-status = pkgs.writeShellApplication {
    name = "tmux-claude-status";
    runtimeInputs = [pkgs.tmux pkgs.jq];
    text = ''
      [ -n "''${TMUX_PANE:-}" ] || exit 0
      input="$(cat)"
      case "''${1:-}" in
        start)
          tmux set-option -p -t "$TMUX_PANE" @claude idle
          id="$(jq -r '.session_id // empty' <<<"$input")"
          if [ -n "$id" ]; then tmux set-option -p -t "$TMUX_PANE" @claude_session "$id"; fi
          ;;
        end)
          tmux set-option -pu -t "$TMUX_PANE" @claude
          tmux set-option -pu -t "$TMUX_PANE" @claude_session
          ;;
        working | waiting | idle)
          tmux set-option -p -t "$TMUX_PANE" @claude "$1"
          ;;
      esac
    '';
  };

  # prefix a: every pane running Claude Code, the ones waiting on you first,
  # previewing the pane's screen. Picking one switches session, window and
  # pane.
  tmux-pick-claude = pkgs.writeShellApplication {
    name = "tmux-pick-claude";
    runtimeInputs = [pkgs.tmux pkgs.fzf pkgs.gawk pkgs.coreutils];
    text = ''
      tab=$'\t'
      choice="$(
        tmux list-panes -a -F "#{@claude}$tab#{pane_id}$tab#{session_name}:#{window_index}$tab#{pane_title}" |
          awk -F'\t' -v OFS='\t' '
            $1 == "waiting" { print 0, $2, "⏳ waiting", $3, $4 }
            $1 == "working" { print 1, $2, "● working", $3, $4 }
            $1 == "idle"    { print 2, $2, "○ idle", $3, $4 }
          ' |
          sort -s -t "$tab" -k1,1n | cut -f2- |
          fzf ${fzfPopup} --delimiter='\t' --with-nth=2.. \
            --preview 'tmux capture-pane -ep -t {1}' --preview-window=right,55%,follow
      )" || exit 0
      tmux switch-client -t "''${choice%%"$tab"*}"
    '';
  };

  # resurrect hooks bringing Claude conversations back after a restore.
  # `save` records session, window and pane of every pane running Claude,
  # with its session id. `restore` types `claude --resume <id>` into the
  # restored pane at the same position, unless a Claude already reports from
  # it, so a manual restore on a live server leaves running Claudes alone.
  # The keys wait in the pty while resurrect replays the saved screen, and
  # the shell reads them once it starts.
  tmux-claude-resume = pkgs.writeShellApplication {
    name = "tmux-claude-resume";
    runtimeInputs = [pkgs.tmux pkgs.gawk pkgs.coreutils];
    text = ''
      tab=$'\t'
      state="''${XDG_STATE_HOME:-$HOME/.local/state}/tmux/claude-panes.tsv"
      case "''${1:-}" in
        save)
          mkdir -p "$(dirname "$state")"
          tmux list-panes -a -F "#{@claude_session}$tab#{session_name}$tab#{window_index}$tab#{pane_index}" |
            awk -F'\t' '$1 != ""' >"$state.tmp"
          mv "$state.tmp" "$state"
          ;;
        restore)
          [ -f "$state" ] || exit 0
          tmux list-panes -a -F "#{session_name}$tab#{window_index}$tab#{pane_index}$tab#{pane_id}$tab#{@claude}" |
            awk -F'\t' -v OFS='\t' '
              NR == FNR { id[$2 "\t" $3 "\t" $4] = $1; next }
              ($1 "\t" $2 "\t" $3) in id && $5 == "" {
                print $4, id[$1 "\t" $2 "\t" $3]
              }
            ' "$state" - |
            while IFS="$tab" read -r pane id; do
              tmux send-keys -t "$pane" "claude --resume $id" Enter
            done
          ;;
      esac
    '';
  };
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

  config.home.packages = [tmux-session tmux-claude-status];

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

      # Room for path-named sessions in the status line (default: 10).
      set -g status-left-length 60

      # Pickers: open sessions, directories (new session), Claude Code panes.
      # The built-in session tree stays on prefix w.
      bind s display-popup -E -w 80% -h 70% "${lib.getExe tmux-pick-session}"
      bind o display-popup -E -w 60% -h 60% -d "#{pane_current_path}" "${lib.getExe tmux-pick-dir}"
      bind a display-popup -E -w 90% -h 80% "${lib.getExe tmux-pick-claude}"
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
        # Continuum saves every 2 min and restores when the server starts;
        # `touch ~/tmux_no_auto_restore` skips the restore. Claude panes are
        # resumed by the resurrect hooks.
        plugin = continuum;
        extraConfig = ''
          set -g @resurrect-capture-pane-contents 'on'
          set -g @resurrect-hook-post-save-all '${lib.getExe tmux-claude-resume} save'
          set -g @resurrect-hook-post-restore-all '${lib.getExe tmux-claude-resume} restore'
          set -g @continuum-restore 'on'
          set -g @continuum-save-interval '2'
        '';
      }
    ];
  };
}
