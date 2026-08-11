{
  config,
  lib,
  ...
}: let
  home = config.home.homeDirectory;
  cursor = config.home.pointerCursor;
in {
  # Fallback screen locker. SUPER+SHIFT+L now locks via caelestia (below);
  # hyprlock stays installed as a manual escape hatch (`hyprlock`) in case
  # caelestia's own PAM auth fails to unlock. It writes ~/.config/hypr/
  # hyprlock.conf and authenticates via the security.pam.services.hyprlock
  # service declared in the NixOS host config.
  programs.hyprlock.enable = true;

  # Hyprland configuration
  # Hyprland is enabled on the host config with `programs.hyprland.enable`
  wayland.windowManager.hyprland = {
    enable = true;

    # Disable package here as this is home-manager config.
    # Hyprland should be enabled in the host config.
    package = null;
    portalPackage = null;

    # HM defaults configType to "lua" (writes hyprland.lua with hl.bind(...),
    # which chokes on plain hyprlang bind strings).
    # Here we force the classic hyprlang format so that
    # `MOD, key, dispatcher, args` binds render to hyprland.conf.
    configType = "hyprlang";
    settings = {
      # Set cursor in the session itself: the greeter (tuigreet -> start-hyprland)
      # never sources hm-session-vars.sh, so pointerCursor's XCURSOR_* vars don't
      # reach Hyprland. Mirror whatever home.pointerCursor defines (and setcursor
      # for already-running clients); no-op if the consumer set no pointerCursor.
      env = lib.optionals cursor.enable [
        "XCURSOR_THEME,${cursor.name}"
        "XCURSOR_SIZE,${toString cursor.size}"
      ];
      exec-once =
        lib.optional cursor.enable "hyprctl setcursor ${cursor.name} ${toString cursor.size}"
        ++ ["qs -c caelestia"];
      # Pin the internal panel to its native mode at 1.0x scale (no scaling).
      monitor = [
        "eDP-1, 1920x1080@60, 0x0, 1.0"
      ];

      input = {
        kb_layout = "fr";
        natural_scroll = true;
        touchpad.natural_scroll = true;
      };
      # Inner gap (window↔window) left at the default 5; outer gap (window↔screen
      # edge) halved from the default 20 to 10.
      general = {
        gaps_in = 5;
        gaps_out = 10;
      };
      bind =
        [
          "SUPER, Return, exec, ghostty"
          "SUPER, Tab, workspace, previous" # toggle back-and-forth with the most recently used workspace
          "SUPER, D, exec, wofi --show drun"
          "SUPER, Q, killactive"
          "SUPER SHIFT, E, exit"
          "SUPER SHIFT, L, exec, caelestia shell lock lock" # lock via caelestia
          "SUPER, B, exec, caelestia-bar-toggle" # toggle bar: always-on <-> reveal-on-hover

          "SUPER, V, togglefloating"
          "SUPER, F, fullscreen"
          "SUPER, H, movefocus, l"
          "SUPER, L, movefocus, r"
          "SUPER, K, movefocus, u"
          "SUPER, J, movefocus, d"
        ]
        ++ builtins.concatMap (i: let
          ws = toString (i + 1);
          # Bind by physical keycode (top number row = code:10..18) rather than
          # the keysym. On AZERTY the digit keysyms 1..9 are Shift-accessed
          # (unshifted they are & é " ...), so "SUPER, 1" wouldn't fire on plain
          # Super+toprow. Keycodes are layout-independent, so Super+<n key> works.
          code = "code:${toString (i + 10)}";
        in [
          "SUPER, ${code}, workspace, ${ws}"
          "SUPER SHIFT, ${code}, movetoworkspace, ${ws}"
        ]) (builtins.genList (x: x) 9);
      windowrule = [
        "match:class ^(firefox)$, workspace 1"
        "match:class ^(zen-beta)$, workspace 1"
        "match:class ^(com\\.mitchellh\\.ghostty)$, workspace 2"
        # Firefox Picture-in-Picture: float it and pin so it follows across workspaces.
        "match:title ^(Picture-in-Picture)$, float on"
        "match:title ^(Picture-in-Picture)$, pin on"
        # Ephemeral floating nmtui launched from the Waybar wifi widget.
        # Custom class dodges the ghostty→workspace-2 rule above, so it floats
        # on whatever workspace you're on and self-closes when nmtui exits.
        "match:class ^(nmtui\\.float)$, float on"
        "match:class ^(nmtui\\.float)$, center on"
        "match:class ^(nmtui\\.float)$, size 800 500"
      ];
      # Mouse: SUPER+drag to move / resize windows.
      bindm = [
        "SUPER, mouse:272, movewindow"
        "SUPER, mouse:273, resizewindow"
      ];

      # Media / hardware keys. Hyprland binds nothing to these by default.
      # wpctl ships with the pipewire/wireplumber stack; brightnessctl comes
      # from the host's systemPackages (for its udev rule).
      #  binde = repeats while held (volume/brightness ramp);
      #  bindl = fires even while the session is locked.
      binde = [
        ", XF86AudioRaiseVolume, exec, wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+"
        ", XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];
      bindl = [
        ", XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
        ", XF86AudioMicMute, exec, wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"
      ];
    };
  };

  # Wallpaper daemon (native to Hyprland).
  # TODO: move the image into the repo (or a stable XDG path) instead of ~/Downloads.
  services.hyprpaper = {
    enable = true;
    settings = {
      preload = ["${home}/Downloads/space.jpeg"];
      wallpaper = [
        {
          monitor = ""; # Targeting all monitor
          path = "${home}/Downloads/space.jpeg";
        }
      ];

      # Drop the Hyprland version/splash text rendered at the bottom-center over
      # the wallpaper (visible on empty workspaces).
      splash = false;
    };
  };
}
