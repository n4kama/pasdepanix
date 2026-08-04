{ lib, pkgs, ... }:
{
  home.packages = [ pkgs.libnotify ]; # notify-send, used by the battery watcher

  # Notification daemon. layer = "overlay" is the load-bearing bit: overlay is the
  # topmost wlroots layer, so notifications draw above fullscreen windows too.
  services.mako = {
    enable = true;
    settings = {
      layer = "overlay";
      "urgency=critical" = {
        default-timeout = 0; # low-battery alert stays until dismissed
        ignore-timeout = true;
      };
    };
  };

  # Start mako in-session so it inherits WAYLAND_DISPLAY (dbus activation would not).
  wayland.windowManager.hyprland.settings.exec-once = lib.mkAfter [ "mako" ];

  # Poll battery every 60s; warn once on crossing below 10% while discharging,
  # re-arm when charging or back above threshold.
  # ponytail: single shared stamp assumes one battery (BAT0); fine here.
  systemd.user.services.battery-alert = {
    Unit.Description = "Low-battery notification";
    Service = {
      Type = "oneshot";
      ExecStart = toString (pkgs.writeShellScript "battery-alert" ''
        threshold=10
        stamp="$XDG_RUNTIME_DIR/battery-alert.warned"
        for bat in /sys/class/power_supply/BAT*; do
          [ -r "$bat/capacity" ] || continue
          cap=$(cat "$bat/capacity")
          if [ "$(cat "$bat/status")" = "Discharging" ] && [ "$cap" -le "$threshold" ]; then
            [ -e "$stamp" ] || { ${pkgs.libnotify}/bin/notify-send -u critical \
              "Battery low" "$cap% remaining — plug in."; touch "$stamp"; }
          else
            rm -f "$stamp"
          fi
        done
      '');
    };
  };

  systemd.user.timers.battery-alert = {
    Unit.Description = "Poll battery for low-battery alert";
    Timer = {
      OnBootSec = "1min";
      OnUnitActiveSec = "1min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
