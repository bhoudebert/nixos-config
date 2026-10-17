{
  pkgs,
  ...
}:

{
  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;                                  # use the RTX 5080
    environmentVariables.OLLAMA_CONTEXT_LENGTH = "65536";
    environmentVariables.OLLAMA_FLASH_ATTENTION = "1";
    environmentVariables.OLLAMA_KV_CACHE_TYPE = "q8_0";     # default is 4096, too small for us
  };

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
