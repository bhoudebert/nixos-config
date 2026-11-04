# AI profile settings shared by NixOS hosts (services.ollama, system service)
# and the standalone Home Manager MacBook setup (services.ollama, launchd agent).
# Host-specific bits (listen address, GPU package) stay in each consumer.
{ pkgs }:

{
  ollamaEnvironment = {
    OLLAMA_CONTEXT_LENGTH = "65536"; # default is 4096, too small for us
    OLLAMA_FLASH_ATTENTION = "1";
    OLLAMA_KV_CACHE_TYPE = "q8_0";
  };

  # Rust toolchain used alongside local models.
  packages = with pkgs; [
    cargo
    clippy
    openssl
    openssl.dev
    pkg-config
    rust-analyzer
    rustc
    rustfmt
  ]
  # On macOS the Xcode CLT clang is the C toolchain; a gcc `cc` would shadow it.
  ++ pkgs.lib.optional (!pkgs.stdenv.hostPlatform.isDarwin) gcc;
}
