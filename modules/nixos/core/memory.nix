{ ... }:

{
  # Keep desktop memory pressure recoverable when a browser or renderer spikes.
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 50;
  };

  boot.kernel.sysctl = {
    # zram is much faster than disk swap, so prefer moving cold pages there.
    "vm.swappiness" = 180;
    "vm.page-cluster" = 0;
  };

  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
  };
}
