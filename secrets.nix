let
  # Public keys allowed to decrypt the repo secrets.
  home = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAEXRM/GJeObPfoI4JcqpW5YsKNGKaOyj4Q/uhOWAzQ1 bhoudebert@gmail.com";
  framework = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMNmqoqviDEblP3Cw1uu0zvDGNI/rWaHNWoGlTJPn+a6 ben@nixos";
in
{
  "secrets/grafana-secret-key.age" = {
    publicKeys = [ home ];
    # Keep the file in ASCII-armored form so it stays readable in git diffs.
    armor = true;
  };

  "secrets/dev-private-hosts.age" = {
    publicKeys = [ home ];
    # Host aliases are still private client/work data, so store them encrypted
    # if they need to live in the public repo.
    armor = true;
  };
}
