{...}: {
  programs.mpv = {
    enable = true;
    config = {
      vo = "gpu-next";
      # Portable: videotoolbox on darwin, vaapi/nvdec on linux.
      hwdec = "auto-safe";
      # Keeps aspect ratio when going fullscreen
      # Needed when using omniwm on macos
      keepaspect-window = false;
    };
  };
}
