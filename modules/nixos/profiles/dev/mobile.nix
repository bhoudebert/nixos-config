{ pkgs, ... }:

let
  # A reproducible Android SDK shared by Android Studio, Gradle, React Native,
  # and command-line builds. Keep version selection on "latest" so it follows
  # the SDK metadata pinned by this repository's nixpkgs revision.
  androidSdk =
    (pkgs.androidenv.composeAndroidPackages {
      numLatestPlatformVersions = 3;
      includeSources = true;
      includeEmulator = true;
      includeSystemImages = true;
      systemImageTypes = [ "google_apis_playstore" ];
      abiVersions = [ "x86_64" ];
      includeCmake = true;
      includeNDK = true;
      extraLicenses = [
        "android-sdk-preview-license"
        "google-gdk-license"
      ];
    }).androidsdk;
in
{
  # The Android SDK and Google images are unfree and require license consent.
  nixpkgs.config.android_sdk.accept_license = true;

  # Android Studio and Gradle both discover this immutable SDK through the
  # conventional variables. Per-project SDK additions should be declared above.
  environment.sessionVariables = {
    ANDROID_HOME = "${androidSdk}/libexec/android-sdk";
    ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
    JAVA_HOME = "${pkgs.jdk17.home}";
  };

  users.users.bhoudebert.packages = with pkgs; [
    # IDE and complete Android SDK (platform/build tools, emulator, images,
    # sources, CMake, and NDK).
    android-studio
    androidSdk

    # Physical-device, APK/AAB, and screen-control tooling.
    android-tools
    bundletool
    scrcpy

    # Android native and React Native build dependencies.
    jdk17
    gradle
    kotlin
    watchman
  ];
}
