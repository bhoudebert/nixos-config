{
  config,
  ...
}:

{
  networking.hostName = "home";

  # Force DRM modesetting early for NVIDIA so Wayland and graphics init behave.
  boot.kernelParams = [
    "nvidia-drm.modeset=1"
    # Keep fbdev/DRM ownership stable across suspend-resume on Wayland.
    "nvidia-drm.fbdev=1"
    # Preserve VRAM state across suspend-resume.
    "nvidia.NVreg_PreserveVideoMemoryAllocations=1"
  ];

  # This workstation uses the proprietary NVIDIA stack for the desktop session.
  services.xserver.videoDrivers = [ "nvidia" ];

  hardware.nvidia = {
    # Required for modern Wayland/NVIDIA paths.
    modesetting.enable = true;
    # Standard power-management toggles for this desktop GPU setup.
    powerManagement.enable = true;
    powerManagement.finegrained = false;
    # The 595/open-module kernel notifier path is newer and this machine shows
    # post-resume display hotplug churn, so keep the explicit NVIDIA sleep hooks.
    powerManagement.kernelSuspendNotifier = false;
    # Prefer the open kernel module variant when available/stable.
    open = true;
    # Installs the NVIDIA control panel utility.
    nvidiaSettings = true;
    # Track the stable packaged driver from the selected kernel set.
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
}
