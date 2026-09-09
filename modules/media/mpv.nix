{...}: {
  programs.mpv = {
    enable = true;
    config = {
      vo = "gpu-next";
      # Portable: videotoolbox on darwin, vaapi/nvdec on linux.
      hwdec = "auto-safe";
      # The default 5.1->2.0 downmix matrix sums past 0 dBFS and hard-clips
      # loud transients (gunshots, impacts) on stereo output. Normalising
      # costs ~8 dB of level, so turn the volume up instead of clipping.
      audio-normalize-downmix = true;
    };
  };
}
