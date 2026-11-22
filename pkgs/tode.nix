{ lib, stdenv, fetchurl, autoPatchelfHook, makeWrapper, code-server, alsa-lib, atk, at-spi2-atk, at-spi2-core, cairo, cups, dbus, expat, fontconfig, freetype, glib, gtk3, libdrm, libxkbcommon, mesa, nspr, nss, pango, systemd, libx11, libxcomposite, libxdamage, libxext, libxfixes, libxrandr, libxcb }:

stdenv.mkDerivation rec {
  pname = "tode";
  version = "0.4.3";
  src = fetchurl {
    url = "https://tode-releases.zenbu-labs.workers.dev/dl/stable/v${version}/tode-linux-x64.tar.gz";
    hash = "sha256-LgsSMhy4PDtCuEUW8punlhiRUxTEWawWJ1zDPpw0AFE=";
  };
  nativeBuildInputs = [ autoPatchelfHook makeWrapper ];
  buildInputs = [ alsa-lib atk at-spi2-atk at-spi2-core cairo cups dbus expat fontconfig freetype glib gtk3 libdrm libxkbcommon mesa nspr nss pango systemd libx11 libxcomposite libxdamage libxext libxfixes libxrandr libxcb ];
  installPhase = ''
    runHook preInstall
    mkdir -p "$out/lib/tode" "$out/bin"
    cp -a . "$out/lib/tode/"
    makeWrapper "$out/lib/tode/node_modules/@zenbu-labs/pixel/electron/dist/pixel" "$out/bin/tode" \
      --set ELECTRON_RUN_AS_NODE 1 \
      --set TODE_CODE_SERVER "${lib.getExe code-server}" \
      --add-flags "$out/lib/tode/dist/main.js"
    runHook postInstall
  '';
  meta = {
    description = "VS Code in the terminal";
    homepage = "https://github.com/zenbu-labs/terminal-code";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
    mainProgram = "tode";
  };
}
