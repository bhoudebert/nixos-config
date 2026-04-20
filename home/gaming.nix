{ lib, pkgs, ... }:

let
  # Libraries exposed via pkg-config for PTS benchmarks that build from source.
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

  # Headers made visible to compilers during local benchmark builds.
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

  # Environment variables used by PTS/vkmark builds so the benchmark can find
  # Vulkan, Wayland, and X11 development files without ad-hoc shell setup.
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
  # Steam plus Proton-GE for Windows game compatibility testing.
  programs.steam = {
    enable = true;
    gamescopeSession.enable = true;
    extraCompatPackages = with pkgs; [
      proton-ge-bin
    ];
  };

  environment.systemPackages =
    with pkgs;
    [
      # Benchmark and runtime overlay tools.
      mangohud
      phoronix-test-suite
      glmark2
      unigine-superposition
      unigine-heaven
      unigine-valley

      # Build tooling and graphics headers for PTS benchmarks such as vkmark.
      gcc
      meson
      ninja
      pkg-config
      vulkan-loader
      vulkan-loader.dev
      vulkan-headers
      vulkan-tools
      assimp.dev
      glm
      libdrm.dev
      libgbm
      libx11.dev
      libxcb.dev
      libxkbcommon.dev
      wayland
      wayland.dev
      wayland-protocols
    ]
    ++ [
      pkgs."libxcb-wm".dev
    ];

  # Do not add pkgs.vkmark here: the current nixpkgs derivation is what broke
  # the system rebuild against the newer Vulkan headers.
  # Keep vkmark on the PTS-installed path for now.

  # Desktop defaults tuned for NVIDIA on this machine, plus local PTS build paths.
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
  } // ptsSessionVariables;

  home-manager.users.bhoudebert = { ... }: {
    # Make sure Steam launches through X11. Some games and overlays still behave
    # more consistently there on this setup than through the default Wayland path.
    home.sessionVariables = ptsSessionVariables;

    home.file.".local/bin/steam" = {
      force = true;
      executable = true;
      text = ''
        #!/bin/sh
        exec env GDK_BACKEND=x11 /run/current-system/sw/bin/steam "$@"
      '';
    };

    # MangoHud overlay used to confirm the active GPU, frame time, clocks, power,
    # and to enable quick benchmark logging.
    xdg.configFile."MangoHud/MangoHud.conf".text = ''
      # On-screen overlay. Toggle with Shift+R+F12.
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
      # Toggle logging with F2; logs go to ~/.local/share/MangoHud/
      output_folder=/home/bhoudebert/.local/share/MangoHud
      log_duration=0
      toggle_logging=F2
    '';
  };
}
