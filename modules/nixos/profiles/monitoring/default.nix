{
  ...
}:

{
  # Monitoring profile:
  # Prometheus, Grafana, exporters, and generated dashboards.
  imports = [
    ./core.nix
    ./dashboard.nix
    ./gpu.nix
    ./docker.nix
  ];
}
