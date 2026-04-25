{
  ...
}:

{
  # Keep the chosen implementation explicit so DBus transitions happen
  # intentionally and are visible in git history.
  services.dbus.implementation = "broker";
}
