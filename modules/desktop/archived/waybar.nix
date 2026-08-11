{...}: {
  # The waybar mpris pill can't read Firefox's MPRIS name directly — Firefox
  # registers it but not as D-Bus-activatable, so waybar errors ("name is not
  # activatable") and the pill stays empty. playerctld runs as a user service
  # exposing an activatable proxy over all players, which the module reads fine.
  services.playerctld.enable = true;

  # Waybar - Status bar.
  # Currently using it with Hyprland as it does not ships a bar of its own.
  # Battery reads straight from /sys/class/power_supply (no polling command).
  #
  # (Started via Hyprland's exec-once rather than the systemd unit, to sidestep
  # the same "output not ready yet" login race hyprpaper hits.)
  programs.waybar = {
    enable = true;
    # Catppuccin Frappé. Solid opaque bar; each module sits in a tinted pill.
    # Font pulls the JetBrainsMono Nerd Font already installed on the host.
    style = ''
      * {
        font-family: "JetBrainsMono Nerd Font", monospace;
        font-size: 20px;
        min-height: 0;
      }

      window#waybar {
        background: transparent;   /* bar itself invisible; pills float */
        color: #c6d0f5;        /* text */
      }

      /* every module rendered as a rounded pill */
      #workspaces,
      #clock,
      #network,
      #mpris,
      #backlight,
      #wireplumber,
      #battery {
        background: #414559;   /* surface0 */
        border-radius: 15px;
        padding: 0 18px;
        margin: 0 4px;
      }

      #clock       { color: #babbf1; }  /* lavender */
      #mpris        { color: #ca9ee6; }  /* mauve */
      #mpris.paused { color: #737994; }  /* overlay0 – dimmed when paused */
      #network     { color: #99d1db; }  /* sky */
      #backlight   { color: #e5c890; }  /* yellow */
      #wireplumber { color: #a6d189; }  /* green */
      #battery     { color: #a6d189; }  /* green */

      #workspaces button        { color: #737994; padding: 0 6px; }  /* overlay0 */
      #workspaces button.active { color: #8caaee; }                 /* blue */
      #workspaces button:hover  { color: #c6d0f5; background: transparent; }

      /* battery pill recolors as it drains (states already defined below) */
      #battery.warning  { color: #ef9f76; }  /* peach */
      #battery.critical { color: #e78284; }  /* red */
    '';
    settings.mainBar = {
      layer = "top";
      position = "top";
      # gap from screen edges so the pills read as floating islands
      margin-top = 8;
      margin-left = 10;
      margin-right = 10;
      modules-left = ["hyprland/workspaces"];
      modules-center = ["clock" "mpris"];
      modules-right = ["network" "backlight" "wireplumber" "battery"];
      clock.format = "{:%a %d %b  %H:%M}";
      # Now-playing readout over MPRIS (D-Bus). Any MPRIS-aware source appears:
      # Spotify natively, Firefox/Chromium for web audio (YouTube, etc). Click
      # toggles play/pause, scroll = prev/next — handled in-module via
      # libplayerctl, so no playerctl CLI on PATH is needed.
      mpris = {
        format = "{player_icon} {dynamic}";
        format-paused = "{status_icon} {dynamic}";
        dynamic-order = ["title" "artist"];  # title = video/song, artist = channel
        # {dynamic} fits whole tags into dynamic-len, dropping one if they don't
        # both fit. Cap each tag and size the budget so title + " - " + artist
        # always fit → both show, each ellipsised only if very long.
        title-len = 32;
        artist-len = 18;
        dynamic-len = 54;               # >= title-len + 3 (" - ") + artist-len
        max-length = 54;                # hard guard so the pill can't grow the bar
        player-icons = {
          default = "";
          spotify = "󰓇";
          firefox = "󰈹";
          chromium = "";
        };
        status-icons.paused = "󰏤";
        tooltip-format = "{title} — {artist}";
      };
      # Brightness readout. Reads /sys/class/backlight directly and updates live
      # via udev when the XF86MonBrightness keys fire. Scroll on the module to
      # nudge brightness (writes need the video-group perms from the udev rule).
      backlight = {
        format = "{percent}% {icon}";
        format-icons = ["󰃞" "󰃟" "󰃠"];
        on-scroll-up = "brightnessctl set 5%+";
        on-scroll-down = "brightnessctl set 5%-";
      };
      # Volume readout, from the same PipeWire sink the volume keys control, so
      # the two stay in sync. Click to toggle mute; scroll to change volume.
      wireplumber = {
        format = "{volume}% {icon}";
        format-muted = "󰝟 muted";
        format-icons = ["󰕿" "󰖀" "󰕾"];
        on-click = "wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle";
        on-scroll-up = "wpctl set-volume -l 1.5 @DEFAULT_AUDIO_SINK@ 5%+";
        on-scroll-down = "wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-";
      };
      # WiFi signal quality. Reads the active connection via libnl; {signalStrength}
      # is 0–100. Icons ramp from weak to full; tooltip shows SSID + exact %.
      network = {
        format-wifi = "{signalStrength}% {icon}";
        format-ethernet = "󰈀";
        format-disconnected = "󰤭";
        format-icons = ["󰤟" "󰤢" "󰤥" "󰤨"];
        tooltip-format-wifi = "{essid} ({signalStrength}%)";
        on-click = "ghostty --class=nmtui.float -e nmtui";
      };
      battery = {
        format = "{capacity}% {icon}";
        format-charging = "{capacity}% 󰂄";
        format-icons = ["󰁺" "󰁼" "󰁾" "󰂀" "󰂂"];
        states = {
          warning = 30;
          critical = 15;
        };
      };
    };
  };
}
