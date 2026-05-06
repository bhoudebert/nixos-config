# Cloud Stack (`modules/nixos/profiles/cloud`)

This profile groups togethers cloud tooling.

## OneDrive

You still need to configure the where and auth before the service can run on its own.

Checking if the service is enabled.

```nix
nix eval --json .#nixosConfigurations."home".config.services.onedrive.enable    
```

Then another command can tell you if and when it is linked.

```shell
systemctl --user list-unit-files onedrive.service 
```
