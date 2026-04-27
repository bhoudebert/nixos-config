{
  config,
  ...
}:

{
  # Force DRM modesetting early for NVIDIA so Wayland and graphics init behave.
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    # Keep fbdev/DRM ownership stable across suspend-resume on Wayland.
    "nvidia-drm.fbdev=1"
    # Preserve VRAM state and let the kernel coordinate NVIDIA resume hooks.
    "nvidia.NVreg_UseKernelSuspendNotifiers=1"
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];

  # EFI boot via systemd-boot.
  boot.loader.systemd-boot.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # 64-bit and 32-bit graphics stacks are both needed for desktop and gaming.
  hardware.graphics = {
    enable = true;
    enable32Bit = true;
  };

  # Xorg/Plasma should use the NVIDIA driver on this host.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Required for modern Wayland/NVIDIA paths.
    modesetting.enable = true;
    # Standard power-management toggles for this desktop GPU setup.
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    # Prefer the open kernel module variant when available/stable.
    open = true;
    # Installs the NVIDIA control panel utility.
    nvidiaSettings = true;
    # Track the stable packaged driver from the selected kernel set.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
