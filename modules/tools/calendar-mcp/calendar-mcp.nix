{
  config,
  lib,
  pkgs,
  ...
}: let
  # calendar-mcp — MCP server that lists macOS Calendar events and Reminders to
  # Claude Code, creates new ones and moves an event to other dates, through
  # EventKit instead of screenshots of Calendar.app. It deletes nothing. It must
  # run as an app bundle of its own; main.swift says why.
  calendar-mcp = pkgs.stdenv.mkDerivation {
    pname = "calendar-mcp";
    version = "1.2";
    src = lib.fileset.toSource {
      root = ./.;
      fileset = lib.fileset.unions [./main.swift ./Info.plist];
    };
    nativeBuildInputs = [pkgs.swift pkgs.rcodesign];
    buildPhase = ''
      swiftc -O -target ${pkgs.stdenv.hostPlatform.darwinArch}-apple-macos14 main.swift -o calendar-mcp
    '';
    # Under libexec, not Applications: home-manager would copy it into
    # ~/Applications, and it is no app to open by hand.
    installPhase = ''
      app=$out/libexec/calendar-mcp.app/Contents
      install -Dm755 calendar-mcp $app/MacOS/calendar-mcp
      install -Dm644 Info.plist $app/Info.plist
    '';
    # Ad hoc signature over the whole bundle, Info.plist included: macOS refuses
    # to launch a bundle whose executable alone is signed. After fixup, which
    # strips the executable and re-signs only it.
    #
    # macOS files the Calendar and Reminders permissions under this signature,
    # so a build that changes the binary (an edit, a Swift bump) may ask again.
    postFixup = ''
      rcodesign sign $out/libexec/calendar-mcp.app
    '';
  };
in {
  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    # A fixed path for Claude Code to launch, so a new build needs no change to
    # ~/.claude.json: the symlink follows the store path.
    xdg.dataFile."calendar-mcp.app".source = "${calendar-mcp}/libexec/calendar-mcp.app";

    # Claude Code keeps its own state in ~/.claude.json, so the file cannot be a
    # nix-managed copy. Every switch merges in mcpServers.calendar alone (user
    # scope: every project) and leaves the rest of the file as is, which also
    # restores the entry if it went missing. Skipped where Claude Code has never
    # run. A session picks up the server when it starts.
    home.activation.calendarMcp = lib.hm.dag.entryAfter ["linkGeneration"] ''
      claudeConfig=${lib.escapeShellArg "${config.home.homeDirectory}/.claude.json"}
      if [ -e "$claudeConfig" ]; then
        merged=$(mktemp)
        ${pkgs.jq}/bin/jq \
          --arg command ${lib.escapeShellArg "${config.xdg.dataHome}/calendar-mcp.app/Contents/MacOS/calendar-mcp"} \
          '.mcpServers.calendar = {type: "stdio", command: $command, args: []}' "$claudeConfig" > "$merged"
        if cmp -s "$merged" "$claudeConfig"; then
          rm "$merged"
        else
          run mv "$merged" "$claudeConfig"
        fi
      fi
    '';
  };
}
