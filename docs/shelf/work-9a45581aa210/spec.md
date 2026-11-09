# Spec: GitHub Actions CI for the `home` and `framework13` configurations

## Goal

Ajouter des jobs GitHub Actions qui vérifient, à chaque push et chaque pull request, que les configurations NixOS `home` (poste fixe) et `framework13` (portable Framework) du flake continuent de s'évaluer et de se construire, afin de détecter une régression avant le `nixos-rebuild` sur la machine.

## Requirements

1. The system SHALL provide a GitHub Actions workflow file under `.github/workflows/` that runs on every `pull_request` and on every `push` to `main`.
2. The workflow SHALL contain one job per host, covering `nixosConfigurations.home` and `nixosConfigurations.framework13`. The jobs SHALL be independent, so a failure of one does not hide the result of the other (no `fail-fast` cancellation).
3. Each host job SHALL build `.#nixosConfigurations.<host>.config.system.build.toplevel`, the same attribute the README documents for evaluation-only testing. This covers the embedded Home Manager user configuration, since Home Manager is a NixOS module in this repo.
4. The workflow SHALL install Nix with flakes and `nix-command` enabled, and SHALL use `flake.lock` as-is (no `nix flake update`). A change to the lock file is therefore tested like any other change.
5. The workflow SHALL be able to evaluate the configs without any private key: it SHALL NOT require decrypting `secrets/*.age` and SHALL NOT use secrets in the repository settings.
6. The workflow SHALL use a Nix binary cache (the GitHub Actions cache or equivalent), so repeated runs do not rebuild unchanged paths. Cache misses SHALL NOT cause failure.
7. The workflow SHALL fail (non-zero status) when evaluation or build of a host fails, and the failure log SHALL name the host (job name = host name).
8. The workflow SHALL run `nix flake check --no-build` (or equivalent) so the flake outputs (`overlays`, `packages`, `nixosConfigurations`) are validated as a whole. This check SHALL run once, not once per host.
9. Concurrent runs for the same ref SHALL cancel the older run (`concurrency` group).
10. The workflow SHALL request only `contents: read` permission.

## Scenarios

1. (Req 1) WHEN a PR is opened or updated THEN the workflow runs. WHEN a commit is pushed to a branch other than `main` with no PR THEN it does not run. WHEN a commit lands on `main` THEN it runs.
2. (Req 2) WHEN `home` fails to build but `framework13` is fine THEN the `framework13` job still completes and is green, and `home` is red.
3. (Req 3) WHEN a module under `modules/nixos/profiles/dev/` introduces an undefined option or a syntax error THEN both host jobs fail at evaluation. WHEN a change only affects `hosts/framework13/` (e.g. `fingerprint.nix`) THEN `framework13` can fail while `home` stays green.
4. (Req 4) WHEN `flake.lock` is bumped and the new nixpkgs removes a used package THEN the job fails. Edge case: with no lock change, a rerun gives the same result (no input drift).
5. (Req 5) WHEN the run happens on a fork PR with no secrets available THEN the job still passes. Edge case: `age.identityPaths` in `modules/nixos/core/secrets.nix` points to a path absent in CI; this must not break the build, because agenix only reads it at activation.
6. (Req 6) WHEN the cache is empty (first run, or cache evicted) THEN the build still succeeds, only slower. WHEN a second run follows with no change THEN no derivation is rebuilt that was cached.
7. (Req 7) WHEN a host fails THEN the check named after that host is red in the PR checks list, and the log shows the Nix error.
8. (Req 8) WHEN a flake output other than the two hosts is broken (e.g. `packages.x86_64-linux.helium`, whose `pkgs/helium.nix` fetches from GitHub) THEN the check job fails. Edge case: `nix flake check --no-build` evaluates every host once; it does not duplicate the host builds.
9. (Req 9) WHEN two pushes arrive on the same PR in a row THEN the first run is cancelled.
10. (Req 10) WHEN the workflow file is read THEN its `permissions:` block grants only `contents: read`.

## Out of scope

- Any change to Nix code, the flake, or the host configurations. Only `.github/workflows/*` (and a short README note) are added.
- The standalone Home Manager module `hosts/macbook-pro/home-manager.nix`: it is not a flake output and needs a Darwin runner. The request names `home` and `framework`.
- Deploying, activating or switching a system; running `nixos-rebuild switch`.
- Secret decryption or `agenix` rekey checks.
- Automatic `flake.lock` updates (e.g. update PRs), linters/formatters (nixfmt, statix), VM tests.
- aarch64 or Darwin builds.

## Conflicts with existing specs

No `spec.md`, design or decision file exists in `docs/` other than this request. The binding document is `README.md`:

- README "evaluation-only testing" (`nix build ... '.#nixosConfigurations."home".config.system.build.toplevel' --no-link`): the CI builds the same attribute for each host, so it stays consistent. README documents only `home`; CI extends it to `framework13`, which `flake.nix` already exposes.
- README "Encrypted Data": the `.age` files are encrypted for a private key. CI never decrypts them (Req 5), so there is no conflict.
- README "Git history may be rewritten": CI triggers on push and PR, not on history; force-push is handled by the concurrency rule (Req 9).
- `flake.nix` pins `nixpkgs` to `nixos-unstable` and allows unfree (`nixpkgs.config.allowUnfree`, `modules/nixos/core/nix.nix`): CI builds unfree packages (NVIDIA, Steam, etc.) through the config, which is allowed by the config itself, so no extra flag is needed. Cache size and build time may be large (see questions).

None contradicted.

## Open questions

1. **Build or evaluate only?** A full `toplevel` build of `home` (gaming, dev, AI, monitoring, NVIDIA) may take a long time and a lot of disk on a free GitHub runner (about 14 GB free; may need a disk cleanup step). The spec asks for a build (Req 3) because "working" is best proven that way. If the runner runs out of disk or time, the fallback is evaluation only (`nix eval ...drvPath`), which would catch option/syntax errors but not build failures. This changes the design and cost, so please confirm which you want.
2. **Binary cache:** is the GitHub Actions cache enough, or do you have a Cachix cache? Cachix would need a secret and conflicts with Req 5 for fork PRs.
3. **"At all point"**: I read it as every push to `main` plus every PR. Do you also want a scheduled (weekly) run to catch upstream `nixos-unstable` drift?
4. **Does `framework13` build in CI today?** I could not check: this sandbox has no Nix (no `mise.toml`/`.tool-versions` declares tools), so no build or evaluation was run. Existing breakage, if any, will surface on the first CI run.
