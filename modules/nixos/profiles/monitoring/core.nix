{
  config,
  lib,
  pkgs,
  ...
}:

let
  hasNvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;
  nodePort = config.services.prometheus.exporters.node.port;
  smartctlPort = config.services.prometheus.exporters.smartctl.port;
  cadvisorPort = config.services.cadvisor.port;
  processPort = config.services.prometheus.exporters.process.port;
  nvidiaPort = config.services.prometheus.exporters.nvidia-gpu.port;
in
{
  age.secrets.grafana-secret-key = {
    file = ../../../../secrets/grafana-secret-key.age;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  environment.systemPackages = with pkgs; [ lm_sensors ];

  systemd.services.prometheus-node-exporter.serviceConfig = {
    AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
    CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
  };

  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9090;
    globalConfig.scrape_interval = "15s";

    exporters = {
      node = {
        enable = true;
        listenAddress = "127.0.0.1";
        enabledCollectors = [ "systemd" "processes" "hwmon" "thermal_zone" "rapl" "textfile" ];
        extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files" ];
      };
      smartctl = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      process = {
        enable = true;
        listenAddress = "127.0.0.1";
        settings.process_names = [
          { name = "steam"; comm = [ "steam" "steamwebhelper" "gamescope" "wineserver" "wine64-preloader" "wine-preloader" "proton" ]; }
          { name = "browser"; comm = [ "firefox" "librewolf" "chromium" "chrome" "brave" "google-chrome-stable" ]; }
          { name = "ide"; comm = [ "code" "code-oss" "nvim" "vim" "emacs" "emacs-pgtk" "idea" "pycharm" "goland" "clion" "webstorm" ]; }
          { name = "build"; comm = [ "cc1" "cc1plus" "g++" "gcc" "ld" "rustc" "cargo" "nix" "nix-build" "nix-instantiate" "nixos-rebuild" "go" "mvn" "gradle" ]; }
          { name = "docker"; comm = [ "dockerd" "containerd" "containerd-shim-runc-v2" "docker-proxy" ]; }
          { name = "monitoring"; comm = [ "grafana-server" "prometheus" "node_exporter" "cadvisor" "process-exporter" "smartctl_exporter" ] ++ lib.optionals hasNvidia [ "nvidia_gpu_export" ]; }
          { name = "{{.Comm}}"; cmdline = [ ".+" ]; }
        ];
      };
    };

    scrapeConfigs =
      [
        { job_name = "node"; static_configs = [ { targets = [ "127.0.0.1:${toString nodePort}" ]; } ]; }
        { job_name = "smartctl"; static_configs = [ { targets = [ "127.0.0.1:${toString smartctlPort}" ]; } ]; }
        { job_name = "cadvisor"; static_configs = [ { targets = [ "127.0.0.1:${toString cadvisorPort}" ]; } ]; }
        { job_name = "process"; static_configs = [ { targets = [ "127.0.0.1:${toString processPort}" ]; } ]; }
      ]
      ++ lib.optionals hasNvidia [
        { job_name = "nvidia_gpu"; static_configs = [ { targets = [ "127.0.0.1:${toString nvidiaPort}" ]; } ]; }
      ];
  };

  services.cadvisor = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = 9580;
    extraOptions = [
      "-docker_only=true"
      "-store_container_labels=true"
      "-containerd=/var/run/docker/containerd/containerd.sock"
      "-containerd-namespace=moby"
    ];
  };
}
