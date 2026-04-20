{ ... }:

{
  # Local-only overrides that are useful on this workstation but should not be
  # committed to the public repo.
  #
  # Fill this block with client- or company-specific host aliases when needed.
  # The empty default keeps the public configuration safe to publish.
  networking.extraHosts = ''
    127.0.0.1 kafka
    127.0.0.1 dms
    127.0.0.1 bff
    127.0.0.1 bringg-adapter
    127.0.0.1 bringg-mock
    127.0.0.1 tdi-mock
    127.0.0.1 ui
  '';
}
