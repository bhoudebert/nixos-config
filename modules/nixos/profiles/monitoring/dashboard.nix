{
  config,
  lib,
  pkgs,
  ...
}:

let
  hasNvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;

  gpuUsageExpr =
    if hasNvidia then
      "nvidia_smi_utilization_gpu_ratio"
    else
      "host_gpu_busy_ratio";

  gpuPowerExpr =
    if hasNvidia then
      "sum(nvidia_smi_power_draw_watts)"
    else
      "host_gpu_power_watts";

  gpuTempExpr =
    if hasNvidia then
      "nvidia_smi_temperature_gpu"
    else
      "host_gpu_temp_celsius";

  gpuMemoryExpr =
    if hasNvidia then
      "nvidia_smi_utilization_memory_ratio"
    else
      "host_gpu_memory_used_bytes / clamp_min(host_gpu_memory_total_bytes, 1)";

  gpuPowerLegend = if hasNvidia then "GPU" else "Selected GPU";

  totalPowerExpr =
    if hasNvidia then
      "(sum(rate(node_rapl_package_joules_total[30s])) + sum(nvidia_smi_power_draw_watts) + 74) * 1.14"
    else
      "sum(rate(node_rapl_package_joules_total[30s])) + host_gpu_power_watts";

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
        id = 1; gridPos = { x = 0; y = 0; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "percentunit"; min = 0; max = 1;
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "green"; value = null; } { color = "yellow"; value = 0.6; } { color = "red"; value = 0.85; } ]; };
        targets = [ { refId = "A"; expr = ''1 - avg(rate(node_cpu_seconds_total{mode="idle"}[1m]))''; } ];
      }
      {
        type = "stat"; title = "Memory Usage";
        id = 2; gridPos = { x = 4; y = 0; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "percentunit"; min = 0; max = 1;
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "green"; value = null; } { color = "yellow"; value = 0.7; } { color = "red"; value = 0.9; } ]; };
        targets = [ { refId = "A"; expr = "1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)"; } ];
      }
      {
        type = "stat"; title = "GPU Usage";
        id = 3; gridPos = { x = 8; y = 0; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "percentunit"; min = 0; max = 1;
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "green"; value = null; } { color = "yellow"; value = 0.6; } { color = "red"; value = 0.85; } ]; };
        targets = [ { refId = "A"; expr = gpuUsageExpr; } ];
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
        targets = [ { refId = "A"; expr = gpuPowerExpr; } ];
      }
      {
        type = "stat"; title = "GPU Temp";
        id = 6; gridPos = { x = 20; y = 0; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "celsius";
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 85; } ]; };
        targets = [ { refId = "A"; expr = gpuTempExpr; } ];
      }
      {
        type = "stat"; title = "CPU Temp";
        id = 7; gridPos = { x = 0; y = 4; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "celsius";
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "green"; value = null; } { color = "yellow"; value = 70; } { color = "red"; value = 90; } ]; };
        targets = [ { refId = "A"; expr = "max(node_hwmon_temp_celsius)"; } ];
      }
      {
        type = "stat"; title = "Total Power";
        id = 8; gridPos = { x = 4; y = 4; w = 4; h = 4; };
        fieldConfig.defaults = { unit = "watt";
          thresholds.mode = "absolute"; thresholds.steps = [
            { color = "blue"; value = null; } { color = "orange"; value = 400; } { color = "red"; value = 600; } ]; };
        targets = [ { refId = "A"; expr = totalPowerExpr; } ];
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
        type = "timeseries"; title = "Temperatures (hwmon + GPU)";
        id = 11; gridPos = { x = 12; y = 8; w = 12; h = 7; };
        fieldConfig.defaults.unit = "celsius";
        targets = [
          { refId = "A"; expr = "node_hwmon_temp_celsius"; legendFormat = "{{chip}} {{sensor}}"; }
          { refId = "B"; expr = gpuTempExpr; legendFormat = gpuPowerLegend; }
        ];
      }
      {
        type = "timeseries"; title = "GPU Utilisation & Memory";
        id = 12; gridPos = { x = 0; y = 15; w = 12; h = 7; };
        fieldConfig.defaults.unit = "percentunit";
        targets = [
          { refId = "A"; expr = gpuUsageExpr; legendFormat = "GPU util"; }
          { refId = "B"; expr = gpuMemoryExpr; legendFormat = "GPU memory"; }
        ];
      }
      {
        type = "timeseries"; title = "Power (CPU + GPU + Total)";
        id = 13; gridPos = { x = 12; y = 15; w = 12; h = 7; };
        fieldConfig.defaults.unit = "watt";
        targets = [
          { refId = "A"; expr = "sum(rate(node_rapl_package_joules_total[30s]))"; legendFormat = "CPU (RAPL)"; }
          { refId = "B"; expr = gpuPowerExpr; legendFormat = gpuPowerLegend; }
          { refId = "C"; expr = totalPowerExpr; legendFormat = "Total"; }
        ];
      }
      {
        type = "timeseries"; title = "Disk I/O";
        id = 14; gridPos = { x = 0; y = 22; w = 12; h = 7; };
        fieldConfig.defaults.unit = "Bps";
        targets = [
          { refId = "A"; expr = ''rate(node_disk_read_bytes_total{device!~"loop.*|dm-.*"}[30s])''; legendFormat = "{{device}} read"; }
          { refId = "B"; expr = ''rate(node_disk_written_bytes_total{device!~"loop.*|dm-.*"}[30s])''; legendFormat = "{{device}} write"; }
        ];
      }
      {
        type = "timeseries"; title = "Network";
        id = 15; gridPos = { x = 12; y = 22; w = 12; h = 7; };
        fieldConfig.defaults.unit = "Bps";
        targets = [
          { refId = "A"; expr = ''rate(node_network_receive_bytes_total{device!~"lo|veth.*|docker.*|br-.*|virbr.*"}[30s])''; legendFormat = "{{device}} rx"; }
          { refId = "B"; expr = ''rate(node_network_transmit_bytes_total{device!~"lo|veth.*|docker.*|br-.*|virbr.*"}[30s])''; legendFormat = "{{device}} tx"; }
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
          { refId = "A"; expr = ''sum by (friendly_name) (rate(container_fs_reads_bytes_total{name!=""}[1m]) * on(name) group_left(friendly_name) docker_container_info)''; legendFormat = "{{friendly_name}} read"; }
          { refId = "B"; expr = ''sum by (friendly_name) (rate(container_fs_writes_bytes_total{name!=""}[1m]) * on(name) group_left(friendly_name) docker_container_info)''; legendFormat = "{{friendly_name}} write"; }
        ];
      }
    ];
  });
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/grafana/dashboards 0755 grafana grafana -"
    "L+ /var/lib/grafana/dashboards/system-overview.json - - - - ${overviewDashboard}"
  ];

  services.grafana = {
    enable = true;
    settings = {
      server = {
        http_addr = "127.0.0.1";
        http_port = 3000;
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
      dashboards.default_home_dashboard_path = "/var/lib/grafana/dashboards/system-overview.json";
    };

    provision = {
      enable = true;
      datasources.settings.datasources = [{
        name = "Prometheus";
        type = "prometheus";
        access = "proxy";
        url = "http://127.0.0.1:9090";
        isDefault = true;
      }];
      dashboards.settings.providers = [{
        name = "default";
        options.path = "/var/lib/grafana/dashboards";
        allowUiUpdates = true;
      }];
    };
  };
}
