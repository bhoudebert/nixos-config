# Monitoring Stack (`modules/nixos/profiles/monitoring`)

Prometheus + Grafana + three exporters, all localhost-only, anonymous
Admin access to Grafana. Configured declaratively from
`modules/nixos/profiles/monitoring/system.nix` and brought up by
`nixos-rebuild switch --flake .#home`.

## Data flow

```
 hardware / containers
    │
    ▼
 kernel interfaces   (/proc, /sys/class/hwmon, /sys/class/powercap,
                      /sys/fs/cgroup, nvidia-smi, containerd socket)
    │
    ▼
 exporters           (four small daemons + a textfile writer,
                      each on its own localhost port)
    │
    ▼
 Prometheus          (127.0.0.1:9090 — scrapes every 15s, writes TSDB)
    │
    ▼
 Grafana             (127.0.0.1:3000 — queries PromQL, renders panels)
    │
    ▼
 your browser
```

Nothing leaves the box. No authentication, no firewall holes, no
outbound traffic.

## Exporters

Each exporter is a standalone process that reads one kind of data and
republishes it as Prometheus-format metrics on a `GET /metrics` HTTP
endpoint. Prometheus itself collects nothing — it only scrapes.

Current lineup: **node** (host), **nvidia-gpu** (GPU), **smartctl**
(drive SMART), **cadvisor** (Docker containers), **process** (per-process
CPU/RAM grouped by name), plus a **textfile** side-channel served by
node_exporter for the container-id → name mapping.

### node_exporter — `127.0.0.1:9100`

Official Prometheus project. Reads only `/proc` and `/sys`. Internally
organized as ~70 **collectors**; we explicitly enable a few extras:

```nix
enabledCollectors = [ "systemd" "processes" "hwmon" "thermal_zone" "rapl" ];
```

Produces metrics like:

- `node_cpu_seconds_total{cpu,mode}` — per-core CPU time by mode
- `node_memory_*` — everything from `/proc/meminfo`
- `node_disk_read_bytes_total{device}` / `node_disk_written_bytes_total`
- `node_network_receive_bytes_total{device}` / `..._transmit_...`
- `node_hwmon_temp_celsius{chip,sensor}` + `node_hwmon_sensor_label{label}`
- `node_rapl_package_joules_total` — CPU package energy counter (used
  with `rate()` to get live power in watts)
- `node_filesystem_*`, `node_load1`, `node_pressure_*`, …

Does ~90% of the heavy lifting in this dashboard.

### nvidia-gpu-exporter — `127.0.0.1:9835`

Third-party (`utkuozdemir/nvidia_gpu_exporter`). Doesn't link against
NVML — it just runs `nvidia-smi --query-gpu=...` on each scrape, parses
the CSV, and exposes the result. Metrics are prefixed `nvidia_smi_`:

- `nvidia_smi_utilization_gpu_ratio`
- `nvidia_smi_utilization_memory_ratio`
- `nvidia_smi_power_draw_watts`
- `nvidia_smi_temperature_gpu`
- `nvidia_smi_memory_used_bytes`, clocks, fan speed

Alternative: NVIDIA's own `dcgm-exporter` uses NVML directly and is more
accurate — but it's datacenter-oriented and overkill here.

### smartctl_exporter — `127.0.0.1:9633`

Wraps `smartmontools`. Runs `smartctl --json --xall` on each drive every
scrape and exposes:

- `smartctl_device_temperature{device}`
- `smartctl_device_power_on_seconds`
- `smartctl_device_media_errors`
- NVMe wear percentage, read/write totals, error counters

Slow-moving data, useful for drive health alerting. Needs root to read
block devices; the NixOS module handles that.

### cAdvisor — `127.0.0.1:9580`

Google's container metrics collector. Reads Linux cgroups directly and
talks to container runtimes via their native APIs (here: Docker's
embedded containerd). Produces `container_*` metrics, one time-series
per container.

Useful metrics:

- `container_cpu_usage_seconds_total` — cumulative CPU time; use `rate()`
- `container_memory_working_set_bytes` — the "real" in-use memory
- `container_fs_reads_bytes_total` / `container_fs_writes_bytes_total`
- `container_last_seen` — gauge; count it for "number of containers"
- `container_spec_memory_limit_bytes` — what `--memory=` was set to

**Caveats on this setup**:

- Per-container **network** metrics are *not populated* by cAdvisor's
  containerd integration (it can't reliably enter each container's
  network namespace). Host-level network stays in `node_exporter`;
  per-container network would require a different exporter (e.g.
  `docker_stats_exporter`).
- By default the `name` label contains the **container ID hash**, not
  the friendly Docker name, because cAdvisor talks to containerd and
  containerd doesn't know about Docker's human names. See "Docker
  integration" below for the workaround.
- The `podman.sock` / `crio.sock` errors in the startup log are
  harmless — cAdvisor probes every known runtime, logs once, moves on.

### process_exporter — `127.0.0.1:9256`

Reads `/proc/<pid>/*` and groups processes by rules you define, so
metrics stay bounded (one series per group, not one per PID). Our
groups:

- `steam` — steam / steamwebhelper / gamescope / wine preloaders / proton
- `browser` — firefox / librewolf / chromium / chrome / brave
- `ide` — code / nvim / vim / emacs / jetbrains IDEs
- `build` — gcc / g++ / ld / rustc / cargo / nix builders / go / mvn / gradle
- `docker` — dockerd / containerd / containerd-shim-runc-v2
- `monitoring` — grafana / prometheus / exporters / cadvisor
- `{{.Comm}}` catch-all — one series per distinct command name

Useful metrics:

- `namedprocess_namegroup_cpu_seconds_total{groupname}` — cumulative
  CPU time per group; use `rate()`
- `namedprocess_namegroup_memory_bytes{groupname,memtype="resident"}` —
  RSS per group
- `namedprocess_namegroup_num_procs{groupname}` — process count
- `namedprocess_namegroup_open_filedesc{groupname}` — FD count

Example "top 10" queries for the EDGE dashboard:

```
topk(10, sum by (groupname) (rate(namedprocess_namegroup_cpu_seconds_total[1m])))
topk(10, sum by (groupname) (namedprocess_namegroup_memory_bytes{memtype="resident"}))
```

## Prometheus — the time-series database

- Listens on `127.0.0.1:9090`.
- `scrape_interval = "15s"` — pulls `/metrics` from each target once
  every 15 seconds.
- `scrapeConfigs` lists one job per exporter; each job targets
  `127.0.0.1:<port>`.
- Storage: `/var/lib/prometheus2/` — append-only TSDB, Gorilla-compressed.
  A few bytes per sample. Expect 100–500 MB steady-state with this
  config.
- **Retention: 15 days** (Prometheus default). Override with
  `services.prometheus.retentionTime = "90d";` or by size with
  `extraFlags = [ "--storage.tsdb.retention.size=5GB" ];`.
- Query language: **PromQL**. Grafana panels use it; you can also poke
  it directly at `http://localhost:9090` → Graph tab.

For longer-term history or multi-host correlation, the usual upgrade is
remote-writing to **VictoriaMetrics** or **Mimir**. For a single home
box it's unnecessary.

## Grafana — the UI

- Listens on `127.0.0.1:3000`.
- State in `/var/lib/grafana/` (its own SQLite DB for user prefs,
  annotations, etc. — **not** for metric storage).
- `provision.datasources` hard-codes the Prometheus connection so no
  first-run setup is needed.
- `provision.dashboards` tells Grafana to watch `/var/lib/grafana/dashboards/`
  and auto-load any JSON it finds.
- `systemd.tmpfiles.rules` drops our generated dashboard JSON (built from
  the Nix attrset via `builtins.toJSON`) into that directory as a symlink
  into the nix store.
- `auth.anonymous.enabled = true` with Admin role + `disable_login_form`
  = zero-friction local access. Safe because the service only binds
  `127.0.0.1`.

## NixOS-specific plumbing

A handful of bits that aren't obvious if you come from other distros:

1. `boot.kernelModules = [ "intel_rapl_common" ]`
   Loads the RAPL driver at boot so `/sys/class/powercap/intel-rapl*`
   exists (works on AMD Ryzen too, despite the name).

2. `systemd.services.prometheus-node-exporter.serviceConfig` adding
   `AmbientCapabilities = [ "CAP_DAC_READ_SEARCH" ]`
   `CapabilityBoundingSet = [ "CAP_DAC_READ_SEARCH" ]`
   Lets node_exporter (running as a sandboxed user) read
   `/sys/class/powercap/*/energy_uj`, which the kernel keeps at mode
   0400 for the Platypus side-channel mitigation.

3. `services.cadvisor.extraOptions` with `-containerd=/var/run/docker/containerd/containerd.sock`
   and `-containerd-namespace=moby`.
   Recent cAdvisor (0.50+) reaches Docker through containerd, not the
   legacy Docker socket. NixOS's Docker ships its embedded containerd
   at that path under the `moby` namespace, so cAdvisor must be told
   explicitly — otherwise it fails to register the Docker factory and
   only shows systemd cgroups.

4. `systemd.services.docker-container-info-exporter` + matching timer
   A tiny oneshot that runs `docker ps --no-trunc --format '{{.ID}}
   {{.Names}}'` every 30s, turns it into a Prometheus textfile
   (`docker_container_info{name=<id>,friendly_name=<name>} 1`) under
   `/var/lib/prometheus-node-exporter-text-files/`. node_exporter's
   **textfile collector** re-exposes it as part of its regular `/metrics`
   output, so Grafana can join cAdvisor series against it and render
   friendly names instead of 64-char hashes.

5. `systemd.tmpfiles.rules`
   Ensures `/var/lib/grafana/dashboards/` and the textfile directory
   exist with correct ownership, and materializes the overview
   dashboard JSON as a symlink each boot.

## Dashboard — "System Overview"

Provisioned from `modules/nixos/profiles/monitoring/system.nix` — do **not** edit it through the
Grafana UI as changes in `/var/lib/grafana/dashboards/` are managed by
systemd-tmpfiles and will be overwritten on rebuild.

Layout:

- Row 1 (stat cards): CPU Usage, Memory, GPU Usage, CPU Power, GPU Power, GPU Temp
- Row 2 (stat cards): CPU Temp (Tctl), Total Power (est.)
- Row 3 (timeseries): CPU per-core, Temperatures (hwmon + GPU)
- Row 4 (timeseries): GPU util / VRAM util, Power (CPU + GPU + Total est.)
- Row 5 (timeseries): Disk I/O (host), Network (host)
- Row 6 (stat cards): Running Containers, Total Container Memory
- Row 7 (timeseries): Container CPU, Container Memory
- Row 8 (timeseries): Container Disk I/O (read/write per container)

### Total Power estimate

Formula in one PromQL line:

```
(sum(rate(node_rapl_package_joules_total[30s])) + sum(nvidia_smi_power_draw_watts) + 74) * 1.14
```

The `74` is a fixed baseline covering components that have no live
sensor — DDR5 RGB DIMMs, NVMe + SATA SSDs, AIO pump, 7 LED fans,
chipset/VRM/mobo, and USB peripherals. The `1.14` is the PSU
efficiency factor for ~88% Gold under typical load. Tweak either
constant directly in `modules/nixos/profiles/monitoring/system.nix` and rebuild.

### Container panels and the friendly-name join

cAdvisor labels each container series with `name=<containerd container
id>` — a 64-char hash. To render a human name, the container panels
each use a PromQL join:

```
sum by (friendly_name) (
  rate(container_cpu_usage_seconds_total{name!=""}[1m])
  * on(name) group_left(friendly_name) docker_container_info
)
```

`docker_container_info` is the textfile metric written by the
`docker-container-info-exporter` oneshot. The `* on(name) group_left`
grafts `friendly_name` onto the cAdvisor series, joining on the shared
`name` (id) label. Then `sum by (friendly_name)` aggregates and names
the resulting series for the legend.

If a container panel shows an **empty legend**, it just means the
textfile hasn't been written yet (first-run race within the first 30s).
Wait a cycle.

## Extending

To add another exporter:

1. Enable it under `services.prometheus.exporters.<name>`.
2. Add a matching entry in `services.prometheus.scrapeConfigs`.
3. Reference its metrics in new dashboard panels.

NixOS ships ~100 first-class exporter options (postgres, nginx, mysqld,
bind, wireguard, zfs, apcupsd, pihole, …). Any Prometheus-compatible
third-party exporter also works — you just run it as a systemd service
and point a scrape target at it.

## Ports summary

| Service                 | Address          | Purpose                |
|-------------------------|------------------|------------------------|
| Grafana                 | 127.0.0.1:3000   | dashboards UI          |
| Prometheus              | 127.0.0.1:9090   | TSDB + query API       |
| node_exporter           | 127.0.0.1:9100   | host metrics + textfile|
| nvidia-gpu-exporter     | 127.0.0.1:9835   | NVIDIA GPU metrics     |
| smartctl_exporter       | 127.0.0.1:9633   | drive SMART metrics    |
| cAdvisor                | 127.0.0.1:9580   | container metrics      |
| process_exporter        | 127.0.0.1:9256   | per-process CPU / RAM  |

All bound to localhost only. Nothing is firewall-exposed.

## Troubleshooting

```sh
# Each exporter exposes plain-text metrics — curl them directly.
curl -s http://localhost:9100/metrics | head
curl -s http://localhost:9835/metrics | head
curl -s http://localhost:9633/metrics | head
curl -s http://localhost:9580/metrics | head
curl -s http://localhost:9256/metrics | head

# Prometheus web UI: inspect scrape targets, run ad-hoc PromQL.
xdg-open http://localhost:9090

# Service status.
systemctl status prometheus prometheus-node-exporter \
  prometheus-nvidia-gpu-exporter prometheus-smartctl-exporter \
  cadvisor grafana

# Docker name mapping (force an immediate refresh, then inspect).
sudo systemctl start docker-container-info-exporter.service
cat /var/lib/prometheus-node-exporter-text-files/docker_container_info.prom

# Disk usage of the TSDB.
sudo du -sh /var/lib/prometheus2/
```

## Related tooling

### MangoHud (in-game overlay)

Installed system-wide via `users.users.bhoudebert.packages`, config
provisioned via home-manager at `~/.config/MangoHud/MangoHud.conf`.
**Not** integrated with Prometheus — it's a realtime on-screen overlay,
which is the right medium for per-frame data.

Enable it for a game:

- Any executable: `mangohud <command>`
- Steam game: *Launch Options* → `mangohud %command%`

In-game hotkeys (per our config):

- `Shift_R+F12` — toggle the overlay
- `Shift_L+F1` — toggle FPS limit
- `F2` — start / stop CSV logging

Logs go to `~/.local/share/MangoHud/<game>-<timestamp>.csv` with columns
like `fps,frametime,cpu_load,gpu_load,cpu_temp,gpu_temp,ram_used,vram_used`.

To surface *historical* FPS in Grafana later (post-game review, not
live), the pattern is:

1. Small systemd oneshot + timer reads the latest log every 30s.
2. Emits `mangohud_fps{game}` / `mangohud_frametime_ms{game}` /
   `mangohud_log_mtime_seconds{game}` to the node_exporter textfile
   directory — same mechanism used for the docker container name
   mapping.
3. Grafana panel on the custom dashboard reads those metrics.

Not wired up yet; implement only if historical FPS graphs are actually
useful.

## Files

- `modules/nixos/profiles/monitoring/system.nix` — the full monitoring module
  (exporters, Prometheus, Grafana, cAdvisor, process_exporter, textfile
  exporter, dashboard JSON, kernel module, capabilities).
- `/var/lib/prometheus2/` — Prometheus TSDB (metric data).
- `/var/lib/grafana/` — Grafana SQLite + provisioned dashboards dir.
- `/var/lib/prometheus-node-exporter-text-files/` — textfile collector
  directory; holds `docker_container_info.prom`, refreshed every 30s.
- `/etc/systemd/system/` — generated unit files for each service.
