# Activation step that sets mcpServers.<name> in claude_desktop_config.json,
# shared by calendar-mcp and vault-mcp.
#
# Claude Desktop writes its own preferences into that file, so it cannot be a
# nix-managed copy: the step merges in this one entry and leaves the rest as is.
# Skipped where Claude Desktop has never run.
#
# Desktop reads the file only at a cold start and writes its in-memory copy back
# while running, so a merge made while it runs is lost. When the merge changes
# the file and Desktop is running, the step says how to apply it.
{
  config,
  lib,
  pkgs,
}: name: command:
lib.hm.dag.entryAfter ["writeBoundary"] ''
  desktopConfig=${lib.escapeShellArg "${config.home.homeDirectory}/Library/Application Support/Claude/claude_desktop_config.json"}
  if [ -e "$desktopConfig" ]; then
    merged=$(mktemp)
    ${pkgs.jq}/bin/jq \
      --arg name ${lib.escapeShellArg name} \
      --arg command ${lib.escapeShellArg command} \
      '.mcpServers[$name] = {command: $command}' "$desktopConfig" > "$merged"
    if cmp -s "$merged" "$desktopConfig"; then
      rm "$merged"
    else
      run mv "$merged" "$desktopConfig"
      if /usr/bin/pgrep -axq Claude; then
        warnEcho "Claude Desktop is running and will revert mcpServers.${name}. Quit it, run $newGenPath/activate, then relaunch it."
      fi
    fi
  fi
''
