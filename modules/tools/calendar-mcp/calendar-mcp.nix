{
  config,
  lib,
  pkgs,
  ...
}: let
  # calendar-mcp — MCP server that lists macOS Calendar events and Reminders to
  # Claude Code and Bosco, creates new ones and edits existing ones, through
  # EventKit instead of screenshots of Calendar.app. It deletes and completes
  # nothing. It must run as an app bundle of its own; main.swift says why.
  calendar-mcp = pkgs.stdenv.mkDerivation {
    pname = "calendar-mcp";
    version = "1.3";
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
    # and an ad hoc one is the binary's hash: any build that changes the binary
    # (an edit, a Swift bump in nixpkgs) asks again. signingPem avoids that.
    postFixup = ''
      rcodesign sign $out/libexec/calendar-mcp.app
    '';
  };
  cfg = config.programs.calendar-mcp;
  src = "${calendar-mcp}/libexec/calendar-mcp.app";
  app = "${config.xdg.dataHome}/calendar-mcp.app";
in {
  options.programs.calendar-mcp.signingPem = lib.mkOption {
    type = with lib.types; nullOr str;
    default = null;
    example = lib.literalExpression "config.sops.secrets.calendar-mcp-signing.path";
    description = ''
      Path to a PEM file holding a code signing private key and its
      certificate, read at activation. When set, the app bundle is copied out
      of the store and signed with it, so macOS files the Calendar and
      Reminders permissions under the certificate instead of the binary's
      hash: they survive rebuilds, and macOS asks only once per certificate.

      A self-signed certificate is enough:

          openssl req -x509 -newkey rsa:2048 -nodes -days 36500 \
            -subj "/CN=calendar-mcp signing" \
            -addext "keyUsage=critical,digitalSignature" \
            -addext "extendedKeyUsage=critical,codeSigning" \
            -keyout key.pem -out cert.pem
          cat key.pem cert.pem > calendar-mcp-signing.pem

      Keep the file secret: anyone with the key can sign a binary that macOS
      treats as this one. When null, the store bundle is linked as is, ad hoc
      signed.
    '';
  };

  config = lib.mkIf pkgs.stdenv.hostPlatform.isDarwin {
    # A fixed path for Claude Code and Bosco to launch, so a new build needs no
    # change to ~/.claude.json: the symlink follows the store path.
    xdg.dataFile."calendar-mcp.app" = lib.mkIf (cfg.signingPem == null) {source = src;};

    # Signed copy at the same path, redone only when the store bundle changes
    # (the store path it came from is kept next to it). While the key is not
    # readable yet (sops-nix decrypts in a launchd agent, after activation on
    # a first switch), the current copy stays, or an unsigned one goes in, and
    # the next switch signs it. No timestamp: signing must not need the network,
    # and the certificate outlives the machine.
    home.activation.calendarMcpSign = lib.mkIf (cfg.signingPem != null) (
      lib.hm.dag.entryAfter ["linkGeneration"] ''
        app=${lib.escapeShellArg app}
        src=${lib.escapeShellArg src}
        pem=${lib.escapeShellArg cfg.signingPem}
        if [ -L "$app" ] || [ ! -d "$app" ] || [ "$(cat "$app.store-path" 2>/dev/null)" != "$src" ]; then
          if [ -r "$pem" ]; then
            run rm -rf "$app.new"
            run cp -R "$src" "$app.new"
            run chmod -R u+w "$app.new"
            run ${pkgs.rcodesign}/bin/rcodesign sign --timestamp-url none --pem-file "$pem" "$app.new"
            run rm -rf "$app"
            run mv "$app.new" "$app"
            echo "$src" | run tee "$app.store-path" > /dev/null
          else
            warnEcho "calendar-mcp: $pem is not readable yet, run the switch again to sign the bundle"
            if [ -L "$app" ] || [ ! -e "$app" ]; then
              run rm -f "$app"
              run cp -R "$src" "$app"
              run chmod -R u+w "$app"
            fi
          fi
        fi
      ''
    );

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
          --arg command ${lib.escapeShellArg "${app}/Contents/MacOS/calendar-mcp"} \
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
