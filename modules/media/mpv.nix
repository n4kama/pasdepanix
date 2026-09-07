{...}: {
  programs.mpv = {
    enable = true;
    config = {
      vo = "gpu-next";
      # Portable: videotoolbox on darwin, vaapi/nvdec on linux.
      hwdec = "auto-safe";
    };
  };
}
