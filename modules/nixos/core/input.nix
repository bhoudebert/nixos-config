{
  ...
}:

{
  # Keep a consistent international US layout across graphical sessions.
  services.xserver.xkb = {
    layout = "us";
    variant = "intl";
    # Caps Lock becomes a Compose key for accents/symbol input.
    options = "compose:caps";
  };

  # Matching console layout for TTY usage outside the desktop.
  console.keyMap = "us-acentos";
}
