{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.tstream;
in {
  # tstream — stream a magnet link straight into a video player. rqbit serves
  # the torrent over HTTP on a random loopback port with all persistence
  # disabled; quitting the player kills it and wipes the temp dir.

  options.programs.tstream.player = lib.mkOption {
    type = with lib.types; listOf str;
    default = ["mpv"];
    example = [
      "/Applications/IINA.app/Contents/MacOS/iina-cli"
      "--keep-running"
      "--no-stdin"
      "--no-resume-playback"
    ];
    description = ''
      Player argv; the stream URL is appended as the last argument. The player
      must block until you quit it — that is what keeps the torrent alive.

      Flags matter for a smooth experience. For IINA, use
      `iina-cli --keep-running --no-stdin --no-resume-playback`:
      `--keep-running` makes iina-cli block instead of returning immediately,
      `--no-stdin` stops it swallowing the terminal, and `--no-resume-playback`
      avoids seeking into a position the stream hasn't downloaded yet.

      The player itself is not installed by this module — IINA is a Homebrew
      cask, and mpv/vlc are usually already in your packages.
    '';
  };

  config.home.packages = [
    (pkgs.writeShellApplication {
      name = "tstream";
      runtimeInputs = with pkgs; [rqbit curl jq coreutils];
      text =
        ''
          player=(${lib.escapeShellArgs cfg.player})
        ''
        + builtins.readFile ./tstream.sh;
    })
  ];
}
