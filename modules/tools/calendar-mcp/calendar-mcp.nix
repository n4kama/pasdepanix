{
  config,
  lib,
  pkgs,
  ...
}: let
  # calendar-mcp — read-only MCP server listing macOS Calendar events and
  # Reminders to Claude Desktop, through EventKit instead of screenshots of
  # Calendar.app. It must run as an app bundle of its own; main.swift says why.
  calendar-mcp = pkgs.stdenv.mkDerivation {
    pname = "calendar-mcp";
    version = "1.0";
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
  # Claude Desktop writes its own preferences into claude_desktop_config.json, so
  # the file cannot be a nix-managed copy. Every switch merges in mcpServers.calendar
  # alone, pointing at this build's store path; the rest of the file is left as
  # is. Skipped where Claude Desktop has never run. Restart Claude Desktop to
  # pick up a new build.
  home.activation.calendarMcp = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin (
    lib.hm.dag.entryAfter ["writeBoundary"] ''
      desktopConfig=${lib.escapeShellArg "${config.home.homeDirectory}/Library/Application Support/Claude/claude_desktop_config.json"}
      if [ -e "$desktopConfig" ]; then
        merged=$(mktemp)
        ${pkgs.jq}/bin/jq \
          --arg command ${calendar-mcp}/libexec/calendar-mcp.app/Contents/MacOS/calendar-mcp \
          '.mcpServers.calendar = {command: $command}' "$desktopConfig" > "$merged"
        run mv "$merged" "$desktopConfig"
      fi
    ''
  );
}
