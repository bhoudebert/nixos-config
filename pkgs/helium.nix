{
  appimageTools,
  fetchurl,
  lib,
}:

let
  pname = "helium";
  version = "0.11.5.1";

  src = fetchurl {
    url = "https://github.com/imputnet/helium-linux/releases/download/${version}/helium-${version}-x86_64.AppImage";
    hash = "sha256-Ni7IZ9UBafr+ss0BcQaRKqmlmJI4IV1jRAJ8jhcodlg=";
  };

  appimageContents = appimageTools.extractType2 {
    inherit pname src version;
  };
in
appimageTools.wrapType2 {
  inherit pname src version;

  extraInstallCommands = ''
    install -Dm444 ${appimageContents}/helium.desktop \
      $out/share/applications/helium.desktop
    install -Dm444 ${appimageContents}/helium.png \
      $out/share/icons/hicolor/256x256/apps/helium.png
  '';

  meta = {
    description = "Privacy-first Chromium-based web browser";
    homepage = "https://github.com/imputnet/helium";
    downloadPage = "https://github.com/imputnet/helium-linux/releases";
    license = with lib.licenses; [ gpl3Only bsd3 ];
    mainProgram = "helium";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
  };
}
