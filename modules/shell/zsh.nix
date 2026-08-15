{pkgs, ...}: {
  programs.zsh = {
    enable = true;
    enableCompletion = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;

    history = {
      size = 10000;
      save = 10000;
      ignoreDups = true;
      share = true;
    };

    shellAliases = import ./aliases.nix {inherit pkgs;};

    profileExtra = ''
      # Only load Homebrew when it's actually present (macOS). On the NixOS host
      # this path doesn't exist, so guard it to avoid a "no such file" error.
      # `env -u HOMEBREW_PATH`: brew's shellenv silently no-ops when it sees an
      # inherited HOMEBREW_PATH already starting with the prefix, which happens
      # when a shell (or a tmux server) descends from a running brew process.
      # Dropping the var forces shellenv to emit the real PATH export.
      [[ -x /opt/homebrew/bin/brew ]] && eval "$(env -u HOMEBREW_PATH /opt/homebrew/bin/brew shellenv)"
      source ~/.orbstack/shell/init.zsh 2>/dev/null || :
    '';

    initContent = ''
      # --- Completion Improvements ---
      # Use visual menu for completion selection
      zstyle ':completion:*' menu select
      # Case-insensitive matching (foo -> Foo)
      zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

      # Reminder to use tmux
      if [ -z "$TMUX" ]; then
        echo "💡 Note to self: 't' joins tmux · 'tt' restores the last saved session"
      fi
    '';
  };

  # Starship: Cross-shell prompt
  programs.starship = {
    enable = true;
    enableZshIntegration = true;
    settings = {
      add_newline = false;
      character = {
        success_symbol = "[➜](bold green)";
        error_symbol = "[➜](bold red)";
      };
    };
  };
}
