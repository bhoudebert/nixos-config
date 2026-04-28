{
  pkgs,
  ...
}:

{
  systemd.tmpfiles.rules = [
    "d /var/lib/prometheus-node-exporter-text-files 0755 root root -"
  ];

  # Export Docker container-name metadata into node_exporter's textfile collector
  # so Grafana panels can show friendly names instead of IDs.
  systemd.services.docker-container-info-exporter = {
    description = "Write docker container id -> name mapping as a node_exporter textfile";
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

  systemd.timers.docker-container-info-exporter = {
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnBootSec = "30s";
      OnUnitActiveSec = "30s";
      Unit = "docker-container-info-exporter.service";
    };
  };
}
