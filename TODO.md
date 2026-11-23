# TODO

## Todo
- Remove the OmniWM native-fullscreen watcher once upstream ships the setting
  Drop omniwm-focus-native-fullscreen from modules/desktop/omniwm/omniwm.nix and set
  focusNativeFullscreenOnWorkspaceSwitch = true in settings.toml (OmniNull/OmniWM#1314).
  Set ipcEnabled back to false if nothing else uses omniwmctl.
