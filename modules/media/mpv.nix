{
  config,
  lib,
  pkgs,
  ...
}: {
  # uosc draws its buttons as ligatures from two bundled fonts. mpv loads any
  # font in `<config>/fonts`, so link them there instead of installing them
  # system-wide; without this the ligature names show up as literal text.
  xdg.configFile."mpv/fonts".source = "${pkgs.mpvScripts.uosc}/share/fonts";

  # home-manager passes `programs.mpv.scripts` to the mpv wrapper rather than
  # this directory, so dropping a file here does not collide with uosc & co.
  xdg.configFile."mpv/scripts/holdspeed.lua".source = ./holdspeed.lua;

  # Finder picks a default app by bundle id, and every copy of mpv is io.mpv.
  # Running `mpv` in a terminal launches the binary inside the store's mpv.app,
  # which makes macOS register that bundle too. With two io.mpv apps the choice
  # is arbitrary, and after a rebuild it can land on the store copy, which runs
  # without the scripts below. So drop every store registration and re-register
  # the copyApps one before setting the handlers.
  home.activation.mpvDefaultApp = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryAfter ["copyApps"] (
      let
        lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";
      in ''
        ${lsregister} -dump | sed -n 's|^path: *\(/nix/store/.*/mpv\.app\) (0x.*|\1|p' | sort -u |
          while read -r app; do
            # Fails on a path already garbage-collected; nothing to drop then.
            run ${lsregister} -u "$app" || true
          done
        run ${lsregister} -f "$HOME/${config.targets.darwin.copyApps.directory}/mpv.app"

        # Bare names are extensions: duti resolves them the way Finder does, so
        # `.webm` lands on org.webmproject.webm rather than the io.mpv.webm mpv
        # declares. Dotted names are UTIs, a fallback for any video or audio type
        # with no handler of its own. Subtitles are left out: mpv cannot play one
        # alone, and that group in its Info.plist also claims public.plain-text.
        mpvTypes=(
          mkv mk3d mp4 m4v mov webm avi wmv asf flv f4v ts m2ts mts m2t
          mpg mpeg vob 3gp 3g2 ogv ogm rm rmvb divx xvid dv hevc 264 y4m nsv nuv
          mp3 flac m4a aac ac3 eac3 dts wav aiff aif caf opus ogg oga mka wma
          public.movie public.video public.audio
        )
        for type in "''${mpvTypes[@]}"; do
          run ${pkgs.duti}/bin/duti -s io.mpv "$type" all
        done
      ''
    )
  );

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
      # Hold for 5x, release to go back. Quitting is `Q`, mpv's own default
      # quit-watch-later, so nothing is lost by freeing `q`.
      q = "script-binding holdspeed/hold-speed";
      "alt+r" = "script-binding holdspeed/reset-settings";
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
