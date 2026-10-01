{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.programs.vault-mcp;

  # vault-mcp — the reference filesystem MCP server, read-write and confined to
  # one directory. A command of its own so every transport runs the same thing:
  # Claude Desktop starts it over stdio, and a network proxy can wrap it later.
  # The server has no delete tool; it can write, edit, move and mkdir.
  vault-mcp = pkgs.writeShellApplication {
    name = "vault-mcp";
    text = ''
      exec ${lib.getExe pkgs.mcp-server-filesystem} ${lib.escapeShellArg cfg.directory}
    '';
  };
in {
  options.programs.vault-mcp.directory = lib.mkOption {
    type = lib.types.nullOr lib.types.str;
    default = null;
    example = "/Users/me/notes";
    description = ''
      Directory exposed to Claude Desktop, read-write. A symlink is resolved
      when the server starts. Null leaves the module inactive.
    '';
  };

  # Restart Claude Desktop to pick up a change.
  config = lib.mkIf (cfg.directory != null && pkgs.stdenv.hostPlatform.isDarwin) {
    home.activation.vaultMcp =
      import ../claude-desktop-mcp.nix {inherit config lib pkgs;} "vault" (lib.getExe vault-mcp);
  };
}
