# GnuPG agent configuration.
#
# Points gpg-agent at a native pinentry so PIN/passphrase prompts work even when
# the agent is invoked without a controlling terminal (e.g. by SOPS when
# decrypting YubiKey-encrypted files). Declarative, portable replacement for a
# hand-written ~/.gnupg/gpg-agent.conf.
#
# Note: hardware bits (YubiKey PINs, on-card keys, touch policy) live on the
# device, not here; SOPS recipients live in each project's .sops.yaml.
{ pkgs, lib, ... }:
let
  # Native pinentry per platform.
  pinentry =
    if pkgs.stdenv.hostPlatform.isDarwin
    then pkgs.pinentry_mac # macOS GUI dialog
    else pkgs.pinentry-gnome3; # NixOS desktop; use pkgs.pinentry-curses on headless hosts
in
{
  home.file.".gnupg/gpg-agent.conf".text = ''
    pinentry-program ${lib.getExe pinentry}
  '';
}
