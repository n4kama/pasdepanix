{...}: {
  # Waybar - Status bar.
  # Currently using it with Hyprland as it does not ships a bar of its own.
  # Battery reads straight from /sys/class/power_supply (no polling command).
  #
  # (Started via Hyprland's exec-once rather than the systemd unit, to sidestep
  # the same "output not ready yet" login race hyprpaper hits.)
  programs.waybar = {
    enable = true;
    settings.mainBar = {
      layer = "top";
      position = "top";
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
