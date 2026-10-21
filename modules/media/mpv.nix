{
  config,
  lib,
  pkgs,
  ...
}: let
  lsregister = "/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister";

  # TEMPORARY, mpv 0.41.0 only: remove when mpv is updated past 0.41.0,
  # which carries these two commits (mpv-player/mpv#18383). On macOS 27 the
  # coreaudio AO fails to start on some channel layouts and leaves its
  # device-change listener registered on freed memory, so mpv segfaults in
  # hotplug_cb whenever an audio device appears or disappears. While this is
  # here, darwin builds mpv from source instead of using the cache.
  # https://github.com/mpv-player/mpv/issues/18274
  mpv-unwrapped =
    if pkgs.stdenv.hostPlatform.isDarwin
    then
      pkgs.mpv-unwrapped.overrideAttrs (old: {
        patches =
          (old.patches or [])
          ++ [
            (pkgs.fetchpatch {
              name = "ao_coreaudio-cleanup-ao-on-init-failure.patch";
              url = "https://github.com/mpv-player/mpv/commit/af067b5ea8.patch";
              hash = "sha256-jKyFxK4bf+7v2iPsMnNNaf3JqgqdMl+3u/XZe5R3Wf0=";
            })
            (pkgs.fetchpatch {
              name = "ao_coreaudio-register-hotplug-after-init.patch";
              url = "https://github.com/mpv-player/mpv/commit/c5d391adba.patch";
              hash = "sha256-cRUy0TiNGDwv9wpCiglHajNJGgLFH1FBffUK2h3J4OI=";
            })
          ];
      })
    else pkgs.mpv-unwrapped;

  # uosc: OSC replacement (mpv's stock one is bare). thumbfast: seekbar
  # thumbnail previews, which uosc picks up automatically when present; it
  # renders them in a second mpv from its PATH, given the same build here.
  scripts = [
    pkgs.mpvScripts.uosc
    (pkgs.mpvScripts.thumbfast.override {inherit mpv-unwrapped;})
    # Queue the rest of the folder when a file is opened, so episodes chain.
    pkgs.mpvScripts.autoload
    # Recently played menu on `h` (its own default binding), drawn by uosc
    # when it is loaded. IINA's Open Recent.
    pkgs.mpvScripts.memo
  ];
in {
  # uosc draws its buttons as ligatures from two bundled fonts. mpv loads any
  # font in `<config>/fonts`, so link them there instead of installing them
  # system-wide; without this the ligature names show up as literal text.
  xdg.configFile."mpv/fonts".source = "${pkgs.mpvScripts.uosc}/share/fonts";

  # The scripts list above goes to the mpv wrapper rather than this directory,
  # so dropping a file here does not collide with uosc & co.
  xdg.configFile."mpv/scripts/holdspeed.lua".source = ./holdspeed.lua;

  # Finder picks a default app by bundle id, and every copy of mpv is io.mpv.
  # Running mpv registers the store bundle its binary lives in, so several
  # io.mpv apps pile up across rebuilds, some of them garbage-collected. Drop
  # every store registration and re-register the copyApps one before setting
  # the handlers, so Finder resolves io.mpv to the app in ~/Applications.
  home.activation.mpvDefaultApp = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryAfter ["copyApps"] ''
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
  );

  # The wrapper's `bin/mpv` execs the unwrapped bundle, which macOS would
  # register as a script-less io.mpv. This `mpv` shadows it and goes through
  # the app instead, whose binary sits in the wrapper's own bundle.
  home.packages = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin [
    (lib.hiPrio (pkgs.writeShellScriptBin "mpv" ''
      exec ${config.programs.mpv.finalPackage}/Applications/mpv.app/Contents/MacOS/mpv "$@"
    ''))
  ];

  programs.mpv = {
    enable = true;
    # Running a binary that lives inside an .app makes macOS register that
    # .app. The stock wrapper execs the binary inside the unwrapped bundle,
    # so every launch, Finder's included, registers a second io.mpv that
    # starts without the scripts. Copying the binary into the wrapper's own
    # bundle means any io.mpv macOS registers is one that loads them.
    package = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
      (pkgs.mpv.override {inherit scripts mpv-unwrapped;}).overrideAttrs (old: let
        stock = ''makeWrapper "${mpv-unwrapped}/Applications/mpv.app/Contents/MacOS/mpv"'';
        own = "$out/Applications/mpv.app/Contents/MacOS/mpv-unwrapped";
        # symlinkJoin bakes postBuild into buildCommand, so patch it there.
        buildCommand =
          builtins.replaceStrings [stock] [
            ''
              cp ${mpv-unwrapped}/Applications/mpv.app/Contents/MacOS/mpv "${own}"
              makeWrapper "${own}"''
          ]
          old.buildCommand;
      in
        assert lib.assertMsg (buildCommand != old.buildCommand) "mpv wrapper changed: the darwin bundle patch no longer applies"; {
          inherit buildCommand;
        })
    );
    # home-manager accepts either `package` or `scripts`, so darwin's patched
    # package above carries the scripts itself.
    scripts = lib.mkIf (!pkgs.stdenv.hostPlatform.isDarwin) scripts;
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
