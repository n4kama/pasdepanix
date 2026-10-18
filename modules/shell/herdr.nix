{
  pkgs,
  lib,
  ...
}: let
  # vim-tmux-navigator for herdr: on C-h/j/k/l, forward the chord to the pane
  # when Vim/Neovim is in the foreground, otherwise move herdr's pane focus.
  # The Neovim half (crossing out of nvim at a split edge) lives in nvim-config.
  vim-herdr-navigation = pkgs.fetchFromGitHub {
    owner = "paulbkim-dev";
    repo = "vim-herdr-navigation";
    rev = "742db891e7d1f9a550b16c01dc8a6763f2b1493a";
    hash = "sha256-Yt82HBBOdY4tjvZVREpQzKoEklJY0aIYU5ZzISdf7fg=";
  };

  # navigate.sh reads the focused pane from HERDR_PANE_ID, which herdr sets for
  # plugin actions; keybinding commands get HERDR_ACTIVE_PANE_ID instead.
  herdr-navigate = pkgs.writeShellApplication {
    name = "herdr-navigate";
    runtimeInputs = [pkgs.jq pkgs.herdr];
    text = ''
      HERDR_PANE_ID="''${HERDR_PANE_ID:-''${HERDR_ACTIVE_PANE_ID:-}}" \
        exec ${pkgs.bash}/bin/bash ${vim-herdr-navigation}/navigate.sh "$@"
    '';
  };

  # Fuzzy workspace switcher: type to filter, Enter focuses, Esc cancels.
  herdr-workspace-pick = pkgs.writeShellApplication {
    name = "herdr-workspace-pick";
    runtimeInputs = [pkgs.jq pkgs.fzf pkgs.herdr];
    text = ''
      id=$(herdr workspace list \
        | jq -r '.result.workspaces[] | "\(.workspace_id)\t\(.number)  \(.label)  [\(.agent_status)]"' \
        | fzf --delimiter='\t' --with-nth=2 --reverse --prompt='workspace> ' \
        | cut -f1) || exit 0
      herdr workspace focus "$id" >/dev/null
    '';
  };

  navigate = key: dir: {
    inherit key;
    type = "shell";
    command = "${lib.getExe herdr-navigate} ${dir}";
    description = "navigate ${dir} (vim/herdr)";
  };
in {
  # Runs alongside tmux, with the tmux module's prefix, split keys and
  # vim-tmux-navigator chords. Session restore is built in, so there is no
  # resurrect/continuum equivalent.
  programs.herdr = {
    enable = true;

    settings = {
      # The config file is a read-only store symlink: herdr must never need to
      # write it, so first-run setup is off and settings change here only.
      onboarding = false;

      # Hosts whose terminal palette is owned by something else override this
      # with "terminal", which draws from the ANSI slots.
      theme.name = lib.mkDefault "catppuccin";

      # nix pins the version; `herdr update` would only fight it.
      update.version_check = false;

      # New tabs open immediately, like tmux windows; rename with prefix+shift+t.
      ui.prompt_new_tab_name = false;

      # Claude Code state changes in background workspaces play no sound;
      # other agents keep herdr's default.
      ui.sound.agents.claude = "off";

      keys = {
        prefix = "ctrl+space";

        # tmux semantics: `v` stacks the new pane below, `h` puts it right.
        split_horizontal = "prefix+v";
        split_vertical = "prefix+h";

        # C-h/j/k/l does pane focus; the arrows are the way out of apps that
        # keep those chords for themselves (lazygit, k9s).
        focus_pane_left = "prefix+left";
        focus_pane_down = "prefix+down";
        focus_pane_up = "prefix+up";
        focus_pane_right = "prefix+right";

        # prefix+s is the fuzzy workspace picker below; built-in actions take
        # precedence over custom commands, so settings moves off it.
        settings = "prefix+shift+s";

        command = [
          (navigate "ctrl+h" "left")
          (navigate "ctrl+j" "down")
          (navigate "ctrl+k" "up")
          (navigate "ctrl+l" "right")
          {
            key = "prefix+s";
            type = "popup";
            command = lib.getExe herdr-workspace-pick;
            description = "fuzzy-switch workspace";
            width = "50%";
            height = "40%";
          }
        ];
      };
    };
  };
}
