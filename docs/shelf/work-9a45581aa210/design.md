# Design: GitHub Actions CI for `home` and `framework13`

Spec: `spec.md` (10 requirements). No ADR: this is a single workflow file, easy to reverse, not a lasting architectural decision.

## Approach

One new file, `.github/workflows/ci.yml`, plus a short "CI" section in `README.md`. No Nix code is touched.

The file has two kinds of jobs, with no dependency between them (so one failure never hides another):

| Job id | Job `name` | What it runs | Req |
|---|---|---|---|
| `flake-check` | `flake-check` | `nix flake check --no-build` | 8 |
| `build` (matrix `host: [home, framework13]`) | `build (${{ matrix.host }})`, which gives checks named `build (home)` and `build (framework13)` | `nix build --no-link --print-build-logs ".#nixosConfigurations.${host}.config.system.build.toplevel"` | 2, 3, 7 |

The host name is quoted inside the attribute path, as in the README (`"home"`), so a future host with a dash or dot in its name still works.

### Workflow skeleton

```yaml
name: CI
on:
  pull_request:
  push:
    branches: [main]
permissions:
  contents: read
concurrency:
  group: ci-${{ github.workflow }}-${{ github.ref }}
  cancel-in-progress: true
jobs:
  flake-check:
    runs-on: ubuntu-latest
    timeout-minutes: 60
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v31      # flakes + nix-command enabled via extra_nix_config
      - uses: nix-community/cache-nix-action@v6  # actions/cache based, no secret
      - run: nix flake check --no-build --print-build-logs
  build:
    runs-on: ubuntu-latest
    timeout-minutes: 360
    strategy:
      fail-fast: false
      matrix:
        host: [home, framework13]
    name: build (${{ matrix.host }})
    steps:
      - free disk space (remove /usr/local/lib/android, /opt/ghc, dotnet, etc.; run `sudo rm -rf` on those paths)
      - actions/checkout, install-nix-action, cache-nix-action (same as above)
      - run: nix build --no-link --print-build-logs ".#nixosConfigurations.\"${{ matrix.host }}\".config.system.build.toplevel"
```

The exact action tags are pinned to a major version when the file is written. The implementer must check that these versions exist and that `cache-nix-action` inputs are valid. This sandbox has no Nix and no network to GitHub Actions, so the workflow cannot be run here.

## How each requirement is met

- **1** `on: pull_request` plus `push: branches: [main]`. A push to a non-main branch with no PR does not run.
- **2** The matrix has `fail-fast: false`. `flake-check` is a separate job, so the three jobs are independent.
- **3** `toplevel` is the attribute from the README. Home Manager is a NixOS module in this flake, so it is covered.
- **4** `install-nix-action` with `extra_nix_config: experimental-features = nix-command flakes`. Nothing runs `nix flake update` or `--recreate-lock-file`. If `flake.lock` is out of sync with `flake.nix`, the build fails. We do not use `--no-write-lock-file`, so a stale lock is not silently fixed.
- **5** No `secrets.*` is referenced. `GITHUB_TOKEN` is passed to Nix as `access-tokens = github.com=${{ secrets.GITHUB_TOKEN }}` to avoid GitHub API rate limits when fetching inputs. This is the built-in, auto-provided token with read-only scope (not a repository setting). On fork PRs it is still present, read-only. If a reviewer reads Req 5 strictly, drop this line; the only cost is possible rate limiting. The `.age` files are only copied into the store. `age.identityPaths` is read at activation, not at build, so the build does not need the key (Scenario 5). The `builtins.pathExists` check in `modules/nixos/profiles/dev/system.nix` sees the committed `.age` file in the checkout.
- **6** `cache-nix-action` saves and restores `/nix/store` through `actions/cache`. It has no secret and works on fork PRs (restore only). A miss means a normal, slower build; the action does not fail on a miss. It uses a key per host, `nix-${{ runner.os }}-${{ matrix.host }}-${{ hashFiles('flake.lock') }}`, and `restore-keys` on the prefix so a lock bump starts from the previous store. GC is limited by the action's `gc-max-store-size` option, because the repository cache quota is 10 GB. The cache is saved only on `main` pushes, to avoid PRs evicting the main cache. PRs can still read the main cache.
- **7** The job name carries the host and `--print-build-logs` shows the Nix error. A non-zero exit fails the job.
- **8** `flake-check` runs once, with `--no-build`. It evaluates all outputs, including `overlays`, `packages.x86_64-linux.helium` and both hosts. It does not build the hosts, so there is no duplicate build, but the hosts are evaluated a second time, which costs a few minutes at most. `pkgs/helium.nix` is a fixed-output fetch and is not built by `--no-build`, so it is only evaluated.
- **9** `concurrency` with `cancel-in-progress: true`, grouped by ref.
- **10** `permissions: contents: read` at the top level.

## Risks and decisions for open questions

1. **Build vs evaluate (spec Q1).** The design builds, as the spec asks. Risk: `home` (NVIDIA, gaming, dev, monitoring) can exceed the free runner disk (about 14 GB free on a fresh `ubuntu-latest`, more after cleanup, about 30 GB) or the 6 h limit. Mitigations are in the file: the disk cleanup step, and a cache that makes the second run fast. Most of the closure comes from cache.nixos.org, so only local derivations are built. **Fallback if the first run fails on disk or time:** change the build step to `nix eval --raw ".#nixosConfigurations.<host>.config.system.build.toplevel.drvPath"` (evaluation only, still names the host). This is a one-line change and does not change the job layout.
2. **Cache (Q2).** GitHub Actions cache, as the spec requires (Req 5/6 exclude Cachix, which needs a secret). I do not use `magic-nix-cache`: it relied on the legacy Actions cache API that GitHub retired, so it is not a safe choice.
3. **Schedule (Q3).** Not added, since the spec's requirements do not include it. Adding `schedule: cron` is a two-line change if wanted.
4. **Unknown current state (Q4).** I could not run Nix here (no Nix installed, no tool file in the repo declaring one), so I did not build or evaluate either host. No result is claimed. I did read the config: nothing in it reads `~/.ssh` or other host paths at evaluation time, and `framework13` is exposed by `flake.nix`. The first CI run is the real test; if it fails on existing breakage, that is a finding, not a CI bug.
5. **Unfree packages.** `nixpkgs.config.allowUnfree = true` is set in `modules/nixos/core/nix.nix`, so no environment flag is needed. Unfree sources (for example NVIDIA, Steam) are fetched at build time and must be reachable from the runner.

## Files touched

- Add `.github/workflows/ci.yml`.
- Edit `README.md`: a short "CI" section next to "evaluation-only testing" that says what the checks do, that they never decrypt secrets, and that `framework13` is covered too.

Nothing else. In particular `hosts/macbook-pro/home-manager.nix` is out of scope (not a flake output, needs Darwin).

## Error handling

Any non-zero Nix exit fails the step and the job. There are no `continue-on-error` steps, except that cache restore and save are best effort (a cache failure does not fail the job). `timeout-minutes` prevents a hung build from using the 6 h default.

## Testing

- Static: run `actionlint` on the workflow if available, and confirm that the YAML parses (`python -c 'import yaml'`).
- Dry run of the exact build command locally by the maintainer: `nix build --no-link '.#nixosConfigurations."framework13".config.system.build.toplevel'`.
- Real validation: open the PR and check the scenarios against the run: three checks appear (`flake-check`, `build (home)`, `build (framework13)`); a second push cancels the first run (Scenario 9); a rerun is faster thanks to the cache (Scenario 6); no step uses a repository secret other than the default read-only token (Scenario 5).

## Alternatives rejected

- **Separate workflow file per host.** More duplication; the matrix gives the same independent per-host checks.
- **`nix flake check` with builds, instead of `build` jobs.** Builds hosts serially in one job, and a failure would not name the host (violates Req 2 and 7).
- **Cachix or Attic cache.** Needs a secret, fails Req 5 on forks.
- **`magic-nix-cache`** (see above).
- **Evaluation only (`nix eval`)** as the default. Cheaper, but does not catch build failures; kept as the fallback.
- **`pull_request` on all pushes (`on: push` without a branch filter).** Would run twice for PR branches; the spec limits push to `main`.
