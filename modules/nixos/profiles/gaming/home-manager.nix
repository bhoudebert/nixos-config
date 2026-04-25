{
  lib,
  pkgs,
  ...
}:

let
  # Same build-time search paths as the system profile so HM can inject them
  # into the user environment too.
  ptsPkgConfigLibs = with pkgs; [
    vulkan-loader.dev
    libx11.dev
    libxcb.dev
    pkgs."libxcb-wm".dev
    wayland.dev
    libdrm.dev
    assimp.dev
    glm
  ];

  ptsIncludeLibs = with pkgs; [
    vulkan-headers
    assimp.dev
    glm
    libx11.dev
    libxcb.dev
    pkgs."libxcb-wm".dev
    wayland.dev
    libdrm.dev
    libgbm
    libxkbcommon.dev
  ];

  ptsSessionVariables = {
    PKG_CONFIG_PATH = lib.concatStringsSep ":" [
      (lib.makeSearchPath "lib/pkgconfig" ptsPkgConfigLibs)
      (lib.makeSearchPath "share/pkgconfig" [ pkgs.wayland-protocols ])
    ];
    CPATH = lib.concatStringsSep ":" [
      (lib.makeSearchPath "include" ptsIncludeLibs)
      "${pkgs.libdrm.dev}/include/libdrm"
    ];
  };
in
{
  home-manager.users.bhoudebert = {
    # User-side build env for benchmark suites launched from the shell.
    home.sessionVariables = ptsSessionVariables;

    # Wrapper to force Steam through X11 on this machine.
    home.file.".local/bin/steam" = {
      force = true;
      executable = true;
      text = ''
        #!/bin/sh
        exec env GDK_BACKEND=x11 /run/current-system/sw/bin/steam "$@"
      '';
    };

    # MangoHud overlay defaults for quick GPU/CPU/frametime inspection.
    xdg.configFile."MangoHud/MangoHud.conf".text = ''
      fps
      frametime
      frame_count
      gpu_stats
      gpu_core_clock
      gpu_mem_clock
      gpu_power
      gpu_temp
      cpu_stats
      cpu_temp
      cpu_power
      ram
      vram
      engine_version
      vulkan_driver
      position=top-left
      font_size=22
      background_alpha=0.4
      toggle_hud=Shift_R+F12
      toggle_fps_limit=Shift_L+F1
      output_folder=/home/bhoudebert/.local/share/MangoHud
      log_duration=0
      toggle_logging=F2
    '';
  };
}
