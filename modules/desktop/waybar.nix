{...}: {
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
      #backlight,
      #wireplumber,
      #battery {
        background: #414559;   /* surface0 */
        border-radius: 15px;
        padding: 0 18px;
        margin: 0 4px;
      }

      #clock       { color: #babbf1; }  /* lavender */
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
      modules-center = ["clock"];
      modules-right = ["network" "backlight" "wireplumber" "battery"];
      clock.format = "{:%a %d %b  %H:%M}";
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
