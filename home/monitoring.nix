{ config, pkgs, lib, ... }:

let
  # Local-only service ports. Keeping them in one place makes the Prometheus
  # scrape targets and Grafana wiring easier to follow.
  grafanaPort = 3000;
  promPort = 9090;

  nodePort = config.services.prometheus.exporters.node.port;
  nvidiaPort = config.services.prometheus.exporters.nvidia-gpu.port;
  smartctlPort = config.services.prometheus.exporters.smartctl.port;
  cadvisorPort = config.services.cadvisor.port;
  processPort = config.services.prometheus.exporters.process.port;

  # Build the default Grafana dashboard declaratively so the full monitoring
  # layout stays versioned in Nix instead of being edited manually in the UI.
  overviewDashboard = pkgs.writeText "system-overview.json" (builtins.toJSON {
    uid = "system-overview";
    title = "System Overview";
    schemaVersion = 39;
    version = 1;
    refresh = "5s";
    time = { from = "now-15m"; to = "now"; };
    timepicker = {};
    templating.list = [];
    annotations.list = [];
    panels = [
      {
        type = "stat"; title = "CPU Usage";
        id = 1; gridPos = { x = 0;  y = 0; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "percentunit"; min = 0; max = 1;
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "green"; value = null; } { color = "yellow"; value = 0.6; } { color = "red"; value = 0.85; } ]; };
        targets = [ { refId = "A"; expr = ''1 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m]))''; } ];
      }
      {
        type = "stat"; title = "Memory Usage";
        id = 2; gridPos = { x = 4;  y = 0; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "percentunit"; min = 0; max = 1;
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "green"; value = null; } { color = "yellow"; value = 0.7; } { color = "red"; value = 0.9; } ]; };
        targets = [ { refId = "A"; expr = "1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)"; } ];
      }
      {
        type = "stat"; title = "GPU Usage";
        id = 3; gridPos = { x = 8;  y = 0; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "percentunit"; min = 0; max = 1;
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "green"; value = null; } { color = "yellow"; value = 0.6; } { color = "red"; value = 0.85; } ]; };
        targets = [ { refId = "A"; expr = "nvidia_smi_utilization_gpu_ratio"; } ];
      }
      {
        type = "stat"; title = "CPU Package Power";
        id = 4; gridPos = { x = 12; y = 0; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "watt";
          thresholds.mode = "absolute"; thresholds.steps = [ { color = "blue"; value = null; } ]; };
        targets = [ { refId = "A"; expr = "sum(rate(node_rapl_package_joules_total[30s]))"; } ];
      }
      {
        type = "stat"; title = "GPU Power";
        id = 5; gridPos = { x = 16; y = 0; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "watt";
          thresholds.mode = "absolute"; thresholds.steps = [ { color = "blue"; value = null; } ]; };
        targets = [ { refId = "A"; expr = "nvidia_smi_power_draw_watts"; } ];
      }
      {
        type = "stat"; title = "GPU Temp";
        id = 6; gridPos = { x = 20; y = 0; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "celsius";
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 85; } ]; };
        targets = [ { refId = "A"; expr = "nvidia_smi_temperature_gpu"; } ];
      }
      {
        type = "stat"; title = "CPU Temp (Tctl)";
        id = 7; gridPos = { x = 0; y = 4; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "celsius";
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 90; } ]; };
        targets = [ { refId = "A";
          expr = ''max(node_hwmon_temp_celsius * on(chip,sensor) group_left(label) node_hwmon_sensor_label{label="Tctl"})''; } ];
      }
      {
        type = "stat"; title = "Total Power (est.)";
        id = 8; gridPos = { x = 4; y = 4; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "watt";
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "blue"; value = null; } { color = "orange"; value = 400; } { color = "red"; value = 600; } ]; };
        targets = [ { refId = "A";
          expr = "(sum(rate(node_rapl_package_joules_total[30s])) + sum(nvidia_smi_power_draw_watts) + 74) * 1.14"; } ];
      }

      {
        type = "timeseries"; title = "CPU per-core";
        id = 10; gridPos = { x = 0; y = 8; w = 12; h = 7; };
        fieldConfig.defaults = { unit = "percentunit"; min = 0; max = 1; };
        targets = [ { refId = "A";
          expr = ''1 - rate(node_cpu_seconds_total{mode="idle"}[30s])'';
          legendFormat = "cpu{{cpu}}"; } ];
      }
      {
        type = "timeseries"; title = "Temperatures (hwmon)";
        id = 11; gridPos = { x = 12; y = 8; w = 12; h = 7; };
        fieldConfig.defaults.unit = "celsius";
        targets = [
          { refId = "A"; expr = "node_hwmon_temp_celsius"; legendFormat = "{{chip}} {{sensor}}"; }
          { refId = "B"; expr = "nvidia_smi_temperature_gpu"; legendFormat = "GPU"; }
        ];
      }
      {
        type = "timeseries"; title = "GPU Utilisation & Memory";
        id = 12; gridPos = { x = 0; y = 15; w = 12; h = 7; };
        fieldConfig.defaults.unit = "percentunit";
        targets = [
          { refId = "A"; expr = "nvidia_smi_utilization_gpu_ratio";    legendFormat = "GPU util"; }
          { refId = "B"; expr = "nvidia_smi_utilization_memory_ratio"; legendFormat = "VRAM util"; }
        ];
      }
      {
        type = "timeseries"; title = "Power (CPU + GPU + Total est.)";
        id = 13; gridPos = { x = 12; y = 15; w = 12; h = 7; };
        fieldConfig.defaults.unit = "watt";
        targets = [
          { refId = "A"; expr = "sum(rate(node_rapl_package_joules_total[30s]))"; legendFormat = "CPU (RAPL)"; }
          { refId = "B"; expr = "sum(nvidia_smi_power_draw_watts)"; legendFormat = "GPU"; }
          { refId = "C"; expr = "(sum(rate(node_rapl_package_joules_total[30s])) + sum(nvidia_smi_power_draw_watts) + 74) * 1.14"; legendFormat = "Total (est.)"; }
        ];
      }
      {
        type = "timeseries"; title = "Disk I/O";
        id = 14; gridPos = { x = 0; y = 22; w = 12; h = 7; };
        fieldConfig.defaults.unit = "Bps";
        targets = [
          { refId = "A"; expr = ''rate(node_disk_read_bytes_total{device!~"loop.*|dm-.*"}[30s])'';    legendFormat = "{{device}} read"; }
          { refId = "B"; expr = ''rate(node_disk_written_bytes_total{device!~"loop.*|dm-.*"}[30s])''; legendFormat = "{{device}} write"; }
        ];
      }
      {
        type = "stat"; title = "Running Containers";
        id = 20; gridPos = { x = 0; y = 29; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "short";
          thresholds.mode = "absolute"; thresholds.steps = [ { color = "blue"; value = null; } ]; };
        targets = [ { refId = "A";
          expr = ''count(count by (name)(container_last_seen{name!=""}))''; } ];
      }
      {
        type = "stat"; title = "Total Container Memory";
        id = 21; gridPos = { x = 4; y = 29; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "bytes";
          thresholds.mode = "absolute"; thresholds.steps = [ { color = "blue"; value = null; } ]; };
        targets = [ { refId = "A";
          expr = ''sum(container_memory_working_set_bytes{name!=""})''; } ];
      }
      {
        type = "timeseries"; title = "Container CPU";
        id = 22; gridPos = { x = 0; y = 33; w = 12; h = 7; };
        fieldConfig.defaults.unit = "percentunit";
        targets = [ { refId = "A";
          expr = ''sum by (friendly_name) (rate(container_cpu_usage_seconds_total{name!=""}[1m]) * on(name) group_left(friendly_name) docker_container_info)'';
          legendFormat = "{{friendly_name}}"; } ];
      }
      {
        type = "timeseries"; title = "Container Memory";
        id = 23; gridPos = { x = 12; y = 33; w = 12; h = 7; };
        fieldConfig.defaults.unit = "bytes";
        targets = [ { refId = "A";
          expr = ''sum by (friendly_name) (container_memory_working_set_bytes{name!=""} * on(name) group_left(friendly_name) docker_container_info)'';
          legendFormat = "{{friendly_name}}"; } ];
      }
      {
        type = "timeseries"; title = "Container Disk I/O";
        id = 24; gridPos = { x = 0; y = 40; w = 24; h = 7; };
        fieldConfig.defaults.unit = "Bps";
        targets = [
          { refId = "A"; expr = ''sum by (friendly_name) (rate(container_fs_reads_bytes_total{name!=""}[1m]) * on(name) group_left(friendly_name) docker_container_info)'';    legendFormat = "{{friendly_name}} read"; }
          { refId = "B"; expr = ''sum by (friendly_name) (rate(container_fs_writes_bytes_total{name!=""}[1m]) * on(name) group_left(friendly_name) docker_container_info)''; legendFormat = "{{friendly_name}} write"; }
        ];
      }
      {
        type = "timeseries"; title = "Network";
        id = 15; gridPos = { x = 12; y = 22; w = 12; h = 7; };
        fieldConfig.defaults.unit = "Bps";
        targets = [
          { refId = "A"; expr = ''rate(node_network_receive_bytes_total{device!~"lo|veth.*|docker.*|br-.*|virbr.*"}[30s])'';  legendFormat = "{{device}} rx"; }
          { refId = "B"; expr = ''rate(node_network_transmit_bytes_total{device!~"lo|veth.*|docker.*|br-.*|virbr.*"}[30s])''; legendFormat = "{{device}} tx"; }
        ];
      }
    ];
  });
in
{
  # Grafana uses this secret to encrypt sensitive values stored in its DB.
  age.secrets.grafana-secret-key = {
    file = ../secrets/grafana-secret-key.age;
    owner = "grafana";
    group = "grafana";
    mode = "0400";
  };

  # Host sensor probing helpers used by the exporters and local troubleshooting.
  environment.systemPackages = with pkgs; [ lm_sensors ];

  # Expose the AMD package energy counters so Prometheus can estimate CPU power.
  boot.kernelModules = [ "intel_rapl_common" ];

  # Allow node_exporter (non-root) to read /sys/class/powercap/.../energy_uj
  # which is owned root:root mode 0400 (Platypus mitigation).
  systemd.services.prometheus-node-exporter.serviceConfig = {
    AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ];
    CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ];
  };

  # Prometheus scrapes every local exporter and stores the resulting time-series.
  services.prometheus = {
    enable = true;
    listenAddress = "127.0.0.1";
    port = promPort;
    globalConfig.scrape_interval = "15s";

    exporters = {
      # Host metrics: CPU, memory, disks, temperatures, RAPL, textfile collector.
      node = {
        enable = true;
        listenAddress = "127.0.0.1";
        enabledCollectors = [ "systemd" "processes" "hwmon" "thermal_zone" "rapl" "textfile" ];
        extraFlags = [ "--collector.textfile.directory=/var/lib/prometheus-node-exporter-text-files" ];
      };
      # NVIDIA metrics via nvidia-smi.
      nvidia-gpu = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      # SMART and drive health metrics.
      smartctl = {
        enable = true;
        listenAddress = "127.0.0.1";
      };
      # Grouped per-process metrics so Grafana can show IDE/browser/build load.
      process = {
        enable = true;
        listenAddress = "127.0.0.1";
        settings.process_names = [
          { name = "steam";      comm = [ "steam" "steamwebhelper" "gamescope" "wineserver" "wine64-preloader" "wine-preloader" "proton" ]; }
          { name = "browser";    comm = [ "firefox" "librewolf" "chromium" "chrome" "brave" "google-chrome-stable" ]; }
          { name = "ide";        comm = [ "code" "code-oss" "nvim" "vim" "emacs" "idea" "pycharm" "goland" "clion" "webstorm" ]; }
          { name = "build";      comm = [ "cc1" "cc1plus" "g++" "gcc" "ld" "rustc" "cargo" "nix" "nix-build" "nix-instantiate" "nixos-rebuild" "go" "mvn" "gradle" ]; }
          { name = "docker";     comm = [ "dockerd" "containerd" "containerd-shim-runc-v2" "docker-proxy" ]; }
          { name = "monitoring"; comm = [ "grafana-server" "prometheus" "node_exporter" "nvidia_gpu_export" "cadvisor" "process-exporter" "smartctl_exporter" ]; }
          { name = "{{.Comm}}"; cmdline = [ ".+" ]; }
        ];
      };
    };

    scrapeConfigs = [
      { job_name = "node";        static_configs = [ { targets = [ "127.0.0.1:${toString nodePort}"      ]; } ]; }
      { job_name = "nvidia_gpu";  static_configs = [ { targets = [ "127.0.0.1:${toString nvidiaPort}"    ]; } ]; }
      { job_name = "smartctl";    static_configs = [ { targets = [ "127.0.0.1:${toString smartctlPort}"  ]; } ]; }
      { job_name = "cadvisor";    static_configs = [ { targets = [ "127.0.0.1:${toString cadvisorPort}"  ]; } ]; }
      { job_name = "process";     static_configs = [ { targets = [ "127.0.0.1:${toString processPort}"   ]; } ]; }
    ];
  };

  # cAdvisor publishes container-level CPU, memory, and filesystem metrics.
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

  # Grafana stays localhost-only, uses anonymous local access, and loads the
  # default dashboard plus Prometheus datasource declaratively.
  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = grafanaPort;
        domain = "localhost";
      };
      analytics.reporting_enabled = false;
      "auth.anonymous" = {
        enabled = true;
        org_role = "Admin";
      };
      "auth.basic".enabled = false;
      "auth".disable_login_form = true;
      security.secret_key = "$__file{${config.age.secrets.grafana-secret-key.path}}";
      users.default_theme = "dark";
      dashboards.default_home_dashboard_path =
        "/var/lib/grafana/dashboards/system-overview.json";
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [{
        name = "Prometheus";
        type = "prometheus";
        access = "proxy";
        url = "http://127.0.0.1:${toString promPort}";
        isDefault = true;
      }];
      dashboards.settings.providers = [{
        name = "default";
        options.path = "/var/lib/grafana/dashboards";
        allowUiUpdates = true;
      }];
    };
  };

  # Ensure the dashboard directory and node_exporter textfile directory exist,
  # then place the generated dashboard JSON where Grafana expects it.
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    "L+ /var/lib/grafana/dashboards/system-overview.json - - - - ${overviewDashboard}"
    "d /var/lib/prometheus-node-exporter-text-files 0755 root root -"
  ];

  # Publishes Docker container-id → friendly-name as a textfile collector
  # metric, so Grafana panels can render short names instead of long hashes.
  systemd.services.docker-container-info-exporter = {
    description = "Write docker container id → name mapping as a node_exporter textfile";
    after = [ "docker.service" ];
    requires = [ "docker.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "docker-container-info-exporter" ''
        set -eu
        dir=/var/lib/prometheus-node-exporter-text-files
        out=$dir/docker_container_info.prom
        tmp=$(${pkgs.coreutils}/bin/mktemp --tmpdir=$dir info.XXXXXX)
        {
          echo "# HELP docker_container_info Docker container friendly name mapping"
          echo "# TYPE docker_container_info gauge"
          ${pkgs.docker}/bin/docker ps --no-trunc --format '{{.ID}} {{.Names}}' | \
            while read -r id name; do
              printf 'docker_container_info{name="%s",friendly_name="%s"} 1\n' "$id" "$name"
            done
        } > "$tmp"
        ${pkgs.coreutils}/bin/chmod 0644 "$tmp"
        ${pkgs.coreutils}/bin/mv "$tmp" "$out"
      '';
    };
  };

  # Refresh the container-name mapping periodically so Grafana labels stay current.
  systemd.timers.docker-container-info-exporter = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      Unit = "docker-container-info-exporter.service";
    };
  };
}
