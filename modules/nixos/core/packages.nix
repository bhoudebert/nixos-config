{
  pkgs,
  ...
}:

{
  # Small baseline toolbox installed system-wide for admin/debug tasks.
  environment.systemPackages = with pkgs; [
    # PCI and GPU hardware inspection.
    pciutils
    mesa-demos
    lshw
    # Core editor and socket/process inspection.
    vim
    lsof
  ];
}
