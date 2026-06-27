{
  pkgs,
  ...
}:

{
  services.ollama.enable = true;

  users.users.bhoudebert.packages = with pkgs; [
    cargo
    clippy
    gcc
    openssl
    openssl.dev
    pkg-config
    rust-analyzer
    rustc
    rustfmt
  ];
}
