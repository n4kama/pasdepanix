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
      eval "$(/opt/homebrew/bin/brew shellenv)"
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
        echo "💡 Note to self: Use the alias 't' to join the tmux session"
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
