# Design: GitHub Actions CI for `home` and `framework13`

Spec: `spec.md` (10 requirements). No ADR: a single workflow file, easy to reverse, not a lasting architectural decision.

Round 2 changes (review feedback): cache policy is now explicit (PR runs restore only, Scenario 6 relaxed); disk cleanup and timeouts are concrete; the final workflow is fixed here; `cancel-in-progress` spares `main`; `flake-check` has no cache; `actionlint` is optional.

## Approach

One new file, `.github/workflows/ci.yml`, plus a short "CI" section in `README.md`. No Nix code is touched. No contradiction with `README.md` or the spec.

Two kinds of jobs, with no dependency between them (one failure never hides another):

| Job id | Check name | What it runs | Req |
|---|---|---|---|
| `flake-check` | `flake-check` | `nix flake check --no-build` | 8 |
| `build` (matrix `host: [home, framework13]`) | `build (home)`, `build (framework13)` | `nix build --no-link --print-build-logs '.#nixosConfigurations."<host>".config.system.build.toplevel'` | 2, 3, 7 |

The host name is quoted inside the attribute path, as in the README, so a future host name with a dash or dot still works.

## Final workflow

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
  # A second push to main must not cancel the run that would save the cache.
  cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}
jobs:
  flake-check:
    runs-on: ubuntu-latest
    timeout-minutes: 30
    steps:
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v31
        with:
          extra_nix_config: |
            experimental-features = nix-command flakes
            access-tokens = github.com=${{ secrets.GITHUB_TOKEN }}
      - run: nix flake check --no-build --print-build-logs
  build:
    name: build (${{ matrix.host }})
    runs-on: ubuntu-latest
    timeout-minutes: 120
    strategy:
      fail-fast: false
      matrix:
        host: [home, framework13]
    steps:
      - name: Free disk space
        uses: jlumbroso/free-disk-space@v1.3.1
        with:
          tool-cache: true
          android: true
          dotnet: true
          haskell: true
          docker-images: true
          swap-storage: true
          large-packages: false   # apt purge is slow (minutes) for little gain
      - uses: actions/checkout@v4
      - uses: cachix/install-nix-action@v31
        with:
          extra_nix_config: |
            experimental-features = nix-command flakes
            access-tokens = github.com=${{ secrets.GITHUB_TOKEN }}
      - uses: nix-community/cache-nix-action@v6
        with:
          primary-key: nix-${{ runner.os }}-${{ matrix.host }}-${{ hashFiles('flake.lock') }}
          restore-prefixes-first-match: nix-${{ runner.os }}-${{ matrix.host }}-
          save: ${{ github.ref == 'refs/heads/main' }}   # PR runs restore only
          gc-max-store-size-linux: 3G
          purge: true
          purge-prefixes: nix-${{ runner.os }}-${{ matrix.host }}-
          purge-created: 0
          purge-primary-key: never
      - run: >-
          nix build --no-link --print-build-logs
          '.#nixosConfigurations."${{ matrix.host }}".config.system.build.toplevel'
```

Implementation note: the action tags and the `cache-nix-action` input names above are my decision, written from memory of each action's README. The sandbox has no network to GitHub, so they could not be checked here. The implementer must compare them with the actions' READMEs and fix an input name if it differs (for example `gc-max-store-size-linux`), without changing the policy below.

## How each requirement is met

- **1** `pull_request` plus `push: branches: [main]`. A push to another branch with no PR does not run.
- **2** `fail-fast: false`; `flake-check` is a separate job with no `needs`.
- **3** `toplevel`, the README attribute. Home Manager is a NixOS module here, so it is covered.
- **4** `install-nix-action` with flakes enabled. Nothing runs `nix flake update` or `--recreate-lock-file`, and no `--no-write-lock-file`, so a stale lock fails the job.
- **5** No repository-settings secret is referenced. `secrets.GITHUB_TOKEN` is kept in `access-tokens`: it is not a repository-settings secret but the token GitHub creates for each run, read-only here (`contents: read`), and present on fork PRs too. Req 5 forbids secrets "in the repository settings", so it holds under that reading. The token only avoids GitHub API rate limits when fetching inputs. The `.age` files are only copied into the store; `age.identityPaths` (`secrets.nix`) is read by agenix at activation, not at build, so the build needs no key.
- **6** See "Cache policy" below.
- **7** Job name carries the host; `--print-build-logs` shows the Nix error; non-zero exit fails the job.
- **8** `flake-check` runs once with `--no-build`: it evaluates all outputs (overlays, `packages.x86_64-linux.helium`, both hosts) without building them. Hosts are evaluated a second time (a few minutes), accepted for a single, clearly named whole-flake check.
- **9** `concurrency` by ref; older runs are cancelled on PR refs. On `main` they are not (see the skeleton comment): the spec's Req 9 says concurrent runs for the same ref "cancel the older run", and Scenario 9 speaks about PRs. The `main` exception is deliberate, so a cache is not lost to a fast second push. The runs on `main` are queued by the same group, and GitHub keeps only the newest pending one.
- **10** `permissions: contents: read` at top level.

## Cache policy (Req 6, Scenario 6 relaxed)

The cache is best effort. Decisions:

1. **Only `main` pushes save.** PR runs restore only (`save: false`). The reason is the repository cache quota of 10 GB: PR saves would evict the `main` entries that every PR uses.
2. **PRs restore the `main` cache** (a PR can read the default branch's cache) through `restore-prefixes-first-match`, so after a lock bump the nearest older store is reused.
3. **Size.** The two host caches are capped with `gc-max-store-size-linux: 3G` each (about 6 GB, leaving room for one older generation until the purge). The store is garbage-collected to that size before saving, so what is saved is the most recent paths. Most of the closure comes from cache.nixos.org, which is fast to refetch; the cache mostly saves the paths that are built locally or fetched from slow sources. `purge` removes older entries with the same prefix after a successful save on `main`.
4. **`flake-check` has no cache.** Its only cost is fetching flake inputs and evaluating; a cache would compete for the quota for no gain.
5. **Scenario 6 is relaxed to:** the first run (empty cache) succeeds, only slower; a rerun *on `main`* or a PR run *after a `main` run for the same lock* does not rebuild what the `main` cache holds. A second push to the *same PR* does **not** benefit from the first push's builds, only from `main`'s cache. If the quota is still exceeded, entries are evicted and builds are slower, but they never fail (cache miss and save failure are not errors).

This changes the wording of Scenario 6 in `spec.md`; that is a deliberate, explicit relaxation, recorded here.

## Disk and time

- Free space on a fresh `ubuntu-latest` is about 14 GB; `jlumbroso/free-disk-space` (Android SDK, .NET, Haskell, tool cache, Docker images, swap) brings it to about 30 GB or more. `large-packages` stays off (slow). Pinned to `v1.3.1`.
- `timeout-minutes`: 120 for `build` (a cold `home` build with NVIDIA/Steam/dev profiles should fit if most paths come from cache.nixos.org; more than that means the build is wrong for a free runner), 30 for `flake-check`. A hung job is stopped at these limits and not at the 6 h default.
- **Fallback if the first run fails on disk or time:** replace the build step with `nix eval --raw '.#nixosConfigurations."<host>".config.system.build.toplevel.drvPath'` (evaluation only; still named by host). One-line change; the job layout is unchanged. The cache step can then be removed.

## Other risks

1. **Unknown current state.** No Nix and no declared tool file here (`mise.toml`, `.tool-versions` absent), so nothing was built or evaluated and no result is claimed. If the first run fails on existing breakage, that is a finding, not a CI bug.
2. **Unfree packages.** `allowUnfree = true` is in `modules/nixos/core/nix.nix`; no environment flag is needed. Unfree sources must be reachable from the runner.
3. **Schedule.** Not added (not in the requirements). `schedule: cron` is a two-line addition.
4. **`magic-nix-cache`** is not used: it depended on the legacy Actions cache API that GitHub retired.

## Files touched

- Add `.github/workflows/ci.yml`.
- Edit `README.md`: a short "CI" section next to "evaluation-only testing": what the checks do, that they never decrypt secrets, that `framework13` is covered, and that the cache is best effort (saved on `main` only).

Out of scope: `hosts/macbook-pro/home-manager.nix` (not a flake output, needs Darwin).

## Error handling

Any non-zero Nix exit fails its step and job. No `continue-on-error`. Cache restore/save failures and misses do not fail the job (the action's default). Timeouts bound hung builds.

## Testing

- Static: `actionlint` is optional (it may not be available); always check that the YAML parses (`python3 -c 'import yaml,sys; yaml.safe_load(open(".github/workflows/ci.yml"))'`). Read the file against the skeleton above.
- The maintainer can try locally: `nix build --no-link '.#nixosConfigurations."framework13".config.system.build.toplevel'`.
- **The first real run on the PR is the validation of action versions and inputs.** Check: three checks appear (`flake-check`, `build (home)`, `build (framework13)`); a second push to the PR cancels the first run (Scenario 9); after the first `main` run, a later run shows a cache restore hit (relaxed Scenario 6); no step uses a secret other than `GITHUB_TOKEN` (Scenario 5); disk does not run out (Risk: fallback above).

## Alternatives rejected

- **PR runs also save the cache.** Satisfies Scenario 6 as written for PRs, but 10 GB quota thrash evicts the `main` cache. Rejected in favour of restore-only.
- **Separate workflow file per host.** More duplication than the matrix.
- **`nix flake check` with builds instead of build jobs.** Serial, and failures would not name the host (Req 2, 7).
- **Cachix or Attic.** Needs a secret, fails Req 5.
- **`magic-nix-cache`.** See above.
- **Evaluation only as default.** Does not catch build failures; kept as the fallback.
- **`push` without a branch filter.** Runs twice for PR branches.
- **`timeout-minutes: 360`.** The platform maximum protects nothing.
