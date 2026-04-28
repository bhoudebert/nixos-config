{
  config,
  lib,
  pkgs,
  ...
}:

let
  hasNvidia = lib.elem "nvidia" config.services.xserver.videoDrivers;

  gpuMetricsExporter = pkgs.writeShellScript "gpu-metrics-exporter" ''
    set -eu

    dir=/var/lib/prometheus-node-exporter-text-files
    out=$dir/gpu.prom
    tmp=$(${pkgs.coreutils}/bin/mktemp --tmpdir="$dir" gpu.XXXXXX)
    trap '${pkgs.coreutils}/bin/rm -f "$tmp"' EXIT

    emit_metric() {
      metric=$1
      labels=$2
      value=$3
      printf '%s{%s} %s\n' "$metric" "$labels" "$value" >> "$tmp"
    }

    normalize_ratio() {
      value=$1
      ${pkgs.gawk}/bin/awk -v value="$value" 'BEGIN { printf "%.6f", value / 100.0 }'
    }

    microwatts_to_watts() {
      value=$1
      ${pkgs.gawk}/bin/awk -v value="$value" 'BEGIN { printf "%.6f", value / 1000000.0 }'
    }

    millideg_to_celsius() {
      value=$1
      ${pkgs.gawk}/bin/awk -v value="$value" 'BEGIN { printf "%.3f", value / 1000.0 }'
    }

    read_first_existing() {
      for path in "$@"; do
        if [ -r "$path" ]; then
          ${pkgs.coreutils}/bin/cat "$path"
          return 0
        fi
      done
      return 1
    }

    read_hwmon_value() {
      card=$1
      shift
      for hwmon in "$card"/device/hwmon/hwmon* "$card"/hwmon/hwmon*; do
        if [ -d "$hwmon" ]; then
          for file in "$@"; do
            if [ -r "$hwmon/$file" ]; then
              ${pkgs.coreutils}/bin/cat "$hwmon/$file"
              return 0
            fi
          done
        fi
      done
      return 1
    }

    select_gpu() {
      amd_dgpu=""
      amd_igpu=""
      intel_igpu=""

      for card in /sys/class/drm/card*; do
        if [ ! -d "$card/device" ]; then
          continue
        fi

        name=$(${pkgs.coreutils}/bin/basename "$card")
        if ! printf '%s\n' "$name" | ${pkgs.gnugrep}/bin/grep -Eq '^card[0-9]+$'; then
          continue
        fi

        vendor=$(${pkgs.coreutils}/bin/cat "$card/device/vendor" 2>/dev/null || true)
        boot_vga=$(${pkgs.coreutils}/bin/cat "$card/device/boot_vga" 2>/dev/null || printf '0')

        case "$vendor" in
          0x1002)
            if [ "$boot_vga" = "0" ] && [ -z "$amd_dgpu" ]; then
              amd_dgpu=$card
            elif [ -z "$amd_igpu" ]; then
              amd_igpu=$card
            fi
            ;;
          0x8086)
            if [ -z "$intel_igpu" ]; then
              intel_igpu=$card
            fi
            ;;
        esac
      done

      if [ -n "$amd_dgpu" ]; then
        printf '%s|amd|discrete|sysfs\n' "$amd_dgpu"
      elif [ -n "$amd_igpu" ]; then
        printf '%s|amd|integrated|sysfs\n' "$amd_igpu"
      elif [ -n "$intel_igpu" ]; then
        printf '%s|intel|integrated|intel_gpu_top\n' "$intel_igpu"
      fi
    }

    emit_headers() {
      cat > "$tmp" <<'EOF'
# HELP host_gpu_info Selected GPU backend and class information
# TYPE host_gpu_info gauge
# HELP host_gpu_busy_ratio Selected GPU utilisation ratio
# TYPE host_gpu_busy_ratio gauge
# HELP host_gpu_power_watts Selected GPU power draw in watts
# TYPE host_gpu_power_watts gauge
# HELP host_gpu_temp_celsius Selected GPU temperature in Celsius
# TYPE host_gpu_temp_celsius gauge
# HELP host_gpu_memory_used_bytes Selected GPU memory usage in bytes
# TYPE host_gpu_memory_used_bytes gauge
# HELP host_gpu_memory_total_bytes Selected GPU memory total in bytes
# TYPE host_gpu_memory_total_bytes gauge
EOF
    }

    collect_intel_busy_percent() {
      raw=$(${pkgs.coreutils}/bin/timeout 3 ${pkgs.intel-gpu-tools}/bin/intel_gpu_top -J -s 1000 -o - 2>/dev/null || true)
      if [ -z "$raw" ]; then
        return 1
      fi

      printf '%s' "$raw" | ${pkgs.jq}/bin/jq -r '
        [
          .. | objects | to_entries[] |
          select((.key | ascii_downcase) | test("busy$")) |
          .value |
          if type == "number" then .
          elif type == "string" then (try capture("(?<n>[0-9]+(\\.[0-9]+)?)").n | tonumber catch empty)
          else empty end
        ] | map(select(. != null)) | max // empty
      ' 2>/dev/null
    }

    emit_headers

    selected=$(select_gpu || true)
    if [ -z "$selected" ]; then
      ${pkgs.coreutils}/bin/chmod 0644 "$tmp"
      ${pkgs.coreutils}/bin/mv "$tmp" "$out"
      exit 0
    fi

    IFS='|' read -r card vendor kind backend <<EOF
$selected
EOF

    labels="vendor=\"$vendor\",kind=\"$kind\",backend=\"$backend\""
    emit_metric host_gpu_info "$labels" 1

    case "$vendor" in
      amd)
        if busy=$(${pkgs.coreutils}/bin/cat "$card/device/gpu_busy_percent" 2>/dev/null); then
          emit_metric host_gpu_busy_ratio "$labels" "$(normalize_ratio "$busy")"
        fi

        power=$(read_hwmon_value "$card" power1_average power1_input 2>/dev/null || true)
        if [ -n "''${power:-}" ]; then
          emit_metric host_gpu_power_watts "$labels" "$(microwatts_to_watts "$power")"
        fi

        temp=$(read_hwmon_value "$card" temp1_input temp2_input edge_input junction_input 2>/dev/null || true)
        if [ -n "''${temp:-}" ]; then
          emit_metric host_gpu_temp_celsius "$labels" "$(millideg_to_celsius "$temp")"
        fi

        vram_used=$(read_first_existing "$card/device/mem_info_vram_used" "$card/device/mem_info_vis_vram_used" 2>/dev/null || true)
        if [ -n "''${vram_used:-}" ]; then
          emit_metric host_gpu_memory_used_bytes "$labels" "$vram_used"
        fi

        vram_total=$(read_first_existing "$card/device/mem_info_vram_total" "$card/device/mem_info_vis_vram_total" 2>/dev/null || true)
        if [ -n "''${vram_total:-}" ]; then
          emit_metric host_gpu_memory_total_bytes "$labels" "$vram_total"
        fi
        ;;

      intel)
        busy=$(collect_intel_busy_percent || true)
        if [ -n "''${busy:-}" ]; then
          emit_metric host_gpu_busy_ratio "$labels" "$(normalize_ratio "$busy")"
        fi

        power=$(read_hwmon_value "$card" power1_average power1_input 2>/dev/null || true)
        if [ -n "''${power:-}" ]; then
          emit_metric host_gpu_power_watts "$labels" "$(microwatts_to_watts "$power")"
        fi

        temp=$(read_hwmon_value "$card" temp1_input temp2_input 2>/dev/null || true)
        if [ -n "''${temp:-}" ]; then
          emit_metric host_gpu_temp_celsius "$labels" "$(millideg_to_celsius "$temp")"
        fi
        ;;
    esac

    ${pkgs.coreutils}/bin/chmod 0644 "$tmp"
    ${pkgs.coreutils}/bin/mv "$tmp" "$out"
  '';
in
{
  environment.systemPackages = with pkgs; [
    amdgpu_top
    intel-gpu-tools
  ];

  services.prometheus.exporters = lib.optionalAttrs hasNvidia {
    nvidia-gpu = {
      enable = true;
      listenAddress = "127.0.0.1";
    };
  };

  systemd.services.gpu-metrics-exporter = lib.mkIf (!hasNvidia) {
    description = "Write selected GPU metrics as a node_exporter textfile";
    serviceConfig = {
      Type = "oneshot";
      ExecStart = gpuMetricsExporter;
    };
  };

  systemd.timers.gpu-metrics-exporter = lib.mkIf (!hasNvidia) {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "20s";
      OnUnitActiveSec = "15s";
      Unit = "gpu-metrics-exporter.service";
    };
  };
}
