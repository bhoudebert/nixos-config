let
  # Public keys allowed to decrypt the repo secrets.
  bhoudebert = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAEXRM/GJeObPfoI4JcqpW5YsKNGKaOyj4Q/uhOWAzQ1 bhoudebert@gmail.com";
in
{
  "secrets/grafana-secret-key.age" = {
    publicKeys = [ bhoudebert ];
    # Keep the file in ASCII-armored form so it stays readable in git diffs.
    armor = true;
  };
}
