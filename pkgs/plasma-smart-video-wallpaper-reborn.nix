{
  stdenv,
  lib,
  fetchFromGitHub,
  cmake,
  extra-cmake-modules,
  gettext,
  glib,
  libplasma,
  qtdeclarative,
  ki18n,
  kcmutils,
  qtmultimedia,
  knighttime,
}:

stdenv.mkDerivation rec {
  pname = "plasma-smart-video-wallpaper-reborn";
  version = "2.16.0-unstable-2026-10-17";

  src = fetchFromGitHub {
    owner = "luisbocanegra";
    repo = "plasma-smart-video-wallpaper-reborn";
    rev = "e31379a8bf4550ece591b0ef6306ae3ec4f02dd7";
    sha256 = "0pz4vyrrs3756h1i729vs8wd3cwwgb1am3pazp0wg52xp2q0kyly";
  };

  nativeBuildInputs = [
    cmake
    extra-cmake-modules
    gettext
  ];

  buildInputs = [
    libplasma
    qtdeclarative
    ki18n
    kcmutils
    qtmultimedia
    knighttime
  ];

  dontWrapQtApps = true;

  postPatch = ''
    substituteInPlace package/contents/ui/tools/gdbus_get_signal.sh \
      --replace-fail "gdbus monitor" "${glib}/bin/gdbus monitor"
  '';

  postInstall = ''
    chmod +x "$out/share/plasma/wallpapers/luisbocanegra.smart.video.wallpaper.reborn/contents/ui/tools/gdbus_get_signal.sh"
  '';

  meta = {
    description = "Plasma 6 wallpaper plugin for local video wallpapers";
    homepage = "https://github.com/luisbocanegra/plasma-smart-video-wallpaper-reborn";
    license = lib.licenses.gpl2Plus;
    platforms = lib.platforms.linux;
  };
}
