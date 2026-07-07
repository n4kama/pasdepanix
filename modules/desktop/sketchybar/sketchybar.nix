{...}: {
  # SketchyBar - A highly customizable macOS status bar replacement
  # See: https://felixkratz.github.io/SketchyBar/setup
  # ponytail: in-store copy, no live-edit — edit these files and re-run `just switch`.

  # SketchyBar expects an executable shell script at ~/.config/sketchybar/sketchybarrc.
  home.file.".config/sketchybar/sketchybarrc" = {
    source = ./sketchybarrc;
    executable = true;
  };

  # Plugin scripts (executable bits are preserved from the store import).
  home.file.".config/sketchybar/plugins" = {
    source = ./plugins;
    recursive = true;
  };
}
