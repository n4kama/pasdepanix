# pasdepanix

Public [home-manager](https://github.com/nix-community/home-manager) modules for
the tools I use day to day: shell, terminal, editor, window manager, etc. **No
secrets, no personal identity, no host-specific values** live here; those stay in
my private config.

## Usage

Add this flake as an input and import the modules:

```nix
{
  # Use my flake as an input or fork this repo and use your own URL
  inputs.pasdepanix.url = "<URL>";

  # in a home-manager configuration:
  imports = [ inputs.pasdepanix.homeManagerModules.default ];
  # ...or cherry-pick:
  imports = [
    inputs.pasdepanix.homeManagerModules.tmux
    inputs.pasdepanix.homeManagerModules.neovim
  ];
}
```

## Modules

| Module | What it configures |
|--------|--------------------|
| `zsh` | Zsh + starship, generic aliases |
| `tmux` | tmux (catppuccin, vim-navigation) |
| `zoxide` | zoxide |
| `ghostty` | Ghostty terminal |
| `gpg` | gpg-agent pinentry (no keys) |
| `neovim` | Neovim packages + symlink to `~/dev/nvim-config` |
| `omniwm` | OmniWM tiling WM (macOS) |
| `aerospace`, `sketchybar` | archived macOS desktop configs |

The Neovim module symlinks `~/.config/nvim` to `~/dev/nvim-config` (a separate
repo). Adjust that path if yours differs. My neovim config is another git
repository and is not included in this flake.

`default` imports the actively-used modules; `aerospace` and `sketchybar` are
kept for reference and not imported by `default`.
