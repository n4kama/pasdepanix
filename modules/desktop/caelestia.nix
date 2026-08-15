{
  pkgs,
  lib,
  ...
}: {
  # NOTE: this only sets values for programs.caelestia.* — that option is
  # defined by caelestia-shell's own home-manager module, not this one. The
  # consuming flake must import both. See README.md.
  programs.caelestia = {
    enable = true;
    cli.enable = true; # `caelestia` CLI — scheme/wallpaper switching etc.
  };

  # Toggle the vertical bar between always-on (bar.persistent) and reveal-on-
  # hover (mouse at the left edge). Caelestia has no IPC for this; it's a value
  # in ~/.config/caelestia/shell.json, which the shell watches and hot-reloads.
  # Bound to SUPER+B in the hyprland module.
  home.packages = [
    (pkgs.writeShellApplication {
      name = "caelestia-bar-toggle";
      runtimeInputs = [pkgs.jq];
      text = ''
        cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/shell.json"
        mkdir -p "$(dirname "$cfg")"
        [ -s "$cfg" ] || echo '{}' > "$cfg"
        # Default (missing key) is always-on, so only an explicit false flips
        # back to persistent. Note: jq '// true' would wrongly treat false as
        # unset (false // true == true) and stick the toggle on hover-mode.
        if [ "$(jq -r '.bar.persistent' "$cfg")" = false ]
        then new=true; else new=false; fi
        tmp="$(mktemp)"
        jq --argjson n "$new" '.bar.persistent = $n | .bar.showOnHover = true' \
          "$cfg" > "$tmp" && mv "$tmp" "$cfg"
      '';
    })
  ];

  # Same Firefox-MPRIS fix the old bar needed: playerctld exposes an
  # activatable D-Bus proxy so MPRIS consumers (Caelestia's dashboard media
  # widget included) can read browser players — Firefox registers its MPRIS
  # name but not as D-Bus-activatable.
  services.playerctld.enable = true;

  # Pin caelestia to Celsius weather, a 24-hour clock, and per-app workspace
  # icons. Weather default is locale-based and this host's LC_MEASUREMENT is
  # en_US (imperial), so it'd otherwise show Fahrenheit; the clock defaults to
  # 12-hour. windowIcons maps a window class to a Material Symbols name (regex
  # or exact `name`) — without an entry the icon comes from the app's desktop
  # entry categories, which misses apps whose class doesn't resolve (zen-beta
  # ships zen-beta.desktop) and falls back to a terminal glyph. Replacing the
  # list drops upstream's default, so its steam mapping is repeated here.
  #
  # shell.json is runtime-owned (caelestia-bar-toggle rewrites it), so we merge
  # the keys in on activation rather than letting HM own the file as a read-only
  # symlink — which would break the toggle and clobber `just switch`.
  home.activation.caelestiaShellDefaults = lib.hm.dag.entryAfter ["writeBoundary"] ''
    cfg="''${XDG_CONFIG_HOME:-$HOME/.config}/caelestia/shell.json"
    run mkdir -p "$(dirname "$cfg")"
    [ -s "$cfg" ] || echo '{}' > "$cfg"
    tmp="$(mktemp)"
    ${pkgs.jq}/bin/jq '.services.useFahrenheit = false
      | .services.useTwelveHourClock = false
      | .bar.workspaces.maxWindowIcons = 3
      | .bar.workspaces.windowIcons = [
          {regex: "zen-beta", icon: "web"},
          {regex: "steam(_app_(default|[0-9]+))?", icon: "sports_esports"}
        ]' "$cfg" > "$tmp" \
      && run mv "$tmp" "$cfg"
  '';
}
