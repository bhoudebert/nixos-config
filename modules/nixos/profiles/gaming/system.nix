{ lib, pkgs, ... }:

let
  # Development outputs used when benchmark suites need to compile Vulkan/X11
  # samples locally instead of running only prebuilt binaries.
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
    # Locate pkg-config metadata for Vulkan/Wayland/X11 benchmark builds.
    PKG_CONFIG_PATH = lib.concatStringsSep ":" [
      (lib.makeSearchPath "lib/pkgconfig" ptsPkgConfigLibs)
      (lib.makeSearchPath "share/pkgconfig" [ pkgs.wayland-protocols ])
    ];
    # Expose required headers to local compilers.
    CPATH = lib.concatStringsSep ":" [
      (lib.makeSearchPath "include" ptsIncludeLibs)
      "${pkgs.libdrm.dev}/include/libdrm"
    ];
  };
in
{
  # Steam plus Proton-GE for Windows game compatibility.
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
      # In-game overlay and benchmarking tools.
      mangohud
      phoronix-test-suite
      glmark2
      unigine-superposition
      unigine-heaven
      unigine-valley
      # Toolchain and graphics SDK bits for benchmark/source builds.
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

  # NVIDIA-oriented runtime defaults for desktop gaming sessions.
  environment.sessionVariables = {
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    LIBVA_DRIVER_NAME = "nvidia";
  } // ptsSessionVariables;
}
