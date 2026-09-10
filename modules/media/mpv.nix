{pkgs, ...}: {
  # uosc draws its buttons as ligatures from two bundled fonts. mpv loads any
  # font in `<config>/fonts`, so link them there instead of installing them
  # system-wide; without this the ligature names show up as literal text.
  xdg.configFile."mpv/fonts".source = "${pkgs.mpvScripts.uosc}/share/fonts";

  programs.mpv = {
    enable = true;
    # uosc: OSC replacement (mpv's stock one is bare). thumbfast: seekbar
    # thumbnail previews, which uosc picks up automatically when present.
    scripts = [
      pkgs.mpvScripts.uosc
      pkgs.mpvScripts.thumbfast
      # Queue the rest of the folder when a file is opened, so episodes chain.
      pkgs.mpvScripts.autoload
      # Recently played menu on `h` (its own default binding), drawn by uosc
      # when it is loaded. IINA's Open Recent.
      pkgs.mpvScripts.memo
    ];
    config = {
      vo = "gpu-next";
      # Portable: videotoolbox on darwin, vaapi/nvdec on linux.
      hwdec = "auto-safe";
      # Keeps aspect ratio when going fullscreen
      # Needed when using omniwm on macos
      keepaspect-window = false;
      # uosc draws its own seek indicator; the stock OSD bar would double up.
      osd-bar = false;
      # No titlebar: uosc draws its own top bar with window controls. Tiling
      # WMs (OmniWM, Hyprland) place the window anyway, so nothing is lost.
      border = false;
      # mpv's built-in preset: ewa_lanczossharp upscaling plus HDR peak
      # percentile and contrast recovery. Cheap on a GPU, visible when
      # upscaling 1080p to a larger panel.
      profile = "high-quality";
      save-position-on-quit = true;
      screenshot-directory = "~/Downloads";
      screenshot-format = "png";
      keep-open = true;
      screenshot-template = "%tY-%tm-%td-%F-%wH-%wM-%wS";
      # Pick up sibling subtitle files with fuzzy name matching.
      sub-auto = "fuzzy";
      alang = "ja,jpn,es,spa,en,eng,fr,fre,fra";
      slang = "fr,fre,fra";
    };
    bindings = {
      w = "add speed -0.1";
      r = "add speed 0.1";
      q = "quit-watch-later";
      v = "cycle sub";
      x = "cycle audio";
      c = "cycle video";
      # Seeking shows nothing: no uosc timeline flash, and `no-osd` suppresses
      # the text message mpv would print in place of the disabled osd-bar.
      RIGHT = "no-osd seek 5";
      LEFT = "no-osd seek -5";
      UP = "no-osd seek 60";
      DOWN = "no-osd seek -60";
      # audio-panel / sub-panel, uosc's track menus.
      X = "script-binding uosc/audio";
      V = "script-binding uosc/subtitles";
      # OpenSubtitles search and the stream quality picker, both built into
      # uosc but unbound by default. Also reachable from its right-click menu.
      "alt+d" = "script-binding uosc/download-subtitles";
      Y = "script-binding uosc/stream-quality";
    };
  };
}
