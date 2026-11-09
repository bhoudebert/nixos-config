# Plan: GitHub Actions CI for `home` and `framework13`

Inputs: `spec.md` (10 requirements), `design.md` (final workflow skeleton, cache policy). `README.md` is the only binding repo document; nothing in this plan contradicts it. The one deliberate change to the spec is the relaxed Scenario 6, already recorded in `design.md` ("Cache policy"). The `main` exception to Req 9 (no cancel on `main`) is also in `design.md`.

Environment: no `mise.toml`, `.mise.toml` or `.tool-versions` exists, so `mise install` has nothing to install. Nix is not available in the sandbox and GitHub is not reachable. Nothing can be built or evaluated here. The implementer must not claim a build result, and must state this in the final answer. Only static checks can run (YAML parse, optional `actionlint`, a grep-based check script).

"Test first" for a CI file: each step starts with a small static check (a shell script run before and after) that fails while the content is missing. The real proof of the workflow is its first run on the PR (last step).

## Step 1: Static check script (the tests), expected to fail

Riskiest part first is the workflow itself, but the checks that define "done" come first.

- Files: add `.github/scripts/check-ci.sh` (POSIX shell, no Nix needed). Do not make it run in CI.
- It asserts on `.github/workflows/ci.yml`, one named check per requirement:
  - file exists and parses as YAML (`python3 -I -c 'import yaml,sys; yaml.safe_load(open(sys.argv[1]))' ...`; if `yaml` is missing, fall back to `ruby -ryaml` or skip with a printed notice, never a silent pass);
  - Req 1: `pull_request` present, `push` with `branches: [main]`;
  - Req 2: `fail-fast: false`; matrix hosts are exactly `home` and `framework13`; no `needs:` anywhere;
  - Req 3: the build command contains `config.system.build.toplevel` and `nixosConfigurations`;
  - Req 4: no `flake update`, `recreate-lock-file`, `no-write-lock-file`; `nix-command flakes` present;
  - Req 5: no `secrets.` reference other than `secrets.GITHUB_TOKEN`; no `agenix`, `age -d`, or `identity`;
  - Req 6: a cache action is present in `build`, and not in `flake-check`;
  - Req 7: `name: build (${{ matrix.host }})`, `--print-build-logs`, no `continue-on-error`;
  - Req 8: `nix flake check --no-build` appears exactly once;
  - Req 9: `concurrency:` with `cancel-in-progress`;
  - Req 10: `permissions:` has exactly `contents: read` and no job-level `permissions`;
  - timeouts: `timeout-minutes` set on both jobs.
- Test: run `sh .github/scripts/check-ci.sh`. It must fail now (file missing). Running it is the "red" state.
- Decision for the implementer: if the script grows large, keep it. Small is enough; it is a guard for this change, not a product. If it feels like over-engineering, it may live outside the repo (in `$TMPDIR`) and not be committed. State the choice in the commit message.

## Step 2: Workflow skeleton, `flake-check` job only, plus the triggers (Req 1, 4, 5, 8, 9, 10)

- Files: add `.github/workflows/ci.yml`.
- Write the top part of the `design.md` "Final workflow": `name`, `on`, `permissions`, `concurrency` (with the `main` exception), and the `flake-check` job (checkout, `cachix/install-nix-action@v31` with flakes and `access-tokens`, `nix flake check --no-build --print-build-logs`, `timeout-minutes: 30`).
- Test: `sh .github/scripts/check-ci.sh` now passes the trigger, permissions, concurrency, lock, secrets, and flake-check checks; the host/matrix checks are still red. Also the YAML parse.

## Step 3: `build` matrix job (Req 2, 3, 6, 7), the risky step

- Files: edit `.github/workflows/ci.yml`.
- Add the `build` job exactly as in `design.md`: matrix `host: [home, framework13]`, `fail-fast: false`, `name: build (${{ matrix.host }})`, `timeout-minutes: 120`, disk cleanup (`jlumbroso/free-disk-space@v1.3.1`), checkout, install-nix, `nix-community/cache-nix-action@v6` with the policy (restore on PRs, save only on `main`, 3G cap, purge settings), and the quoted-attribute `nix build --no-link --print-build-logs`.
- Verify the action tags and input names. The design says they were written from memory and unchecked. If network is available (WebFetch of each action's README/`action.yml`), compare: `install-nix-action` `extra_nix_config`; `free-disk-space` inputs (`tool-cache`, `android`, `dotnet`, `haskell`, `docker-images`, `swap-storage`, `large-packages`); `cache-nix-action` inputs (`primary-key`, `restore-prefixes-first-match`, `save`, `gc-max-store-size-linux`, `purge`, `purge-prefixes`, `purge-created`, `purge-primary-key`). Fix a wrong name without changing the policy. If there is no network, leave the design values and say clearly in the answer that they are unverified.
- Test: `sh .github/scripts/check-ci.sh` passes completely; YAML parses; `actionlint .github/workflows/ci.yml` if installed (otherwise say it was not run). Read the file against the `design.md` skeleton, and check by eye that the `${{ }}` expression inside the single-quoted attribute reaches the shell as `"home"` and `"framework13"` (the shell sees `.#nixosConfigurations."home"...`).

## Step 4: README "CI" section

- Files: edit `README.md`.
- Add a short "CI" section next to "evaluation-only testing": the three checks (`flake-check`, `build (home)`, `build (framework13)`), that they run on PRs and on `main`, that they never decrypt secrets or use repository secrets, that the cache is best effort and saved only on `main`, and the local command for `framework13` (`nix build --no-link '.#nixosConfigurations."framework13".config.system.build.toplevel'`). Mention the evaluation-only fallback only if a reader needs it; keep it short.
- Test: `grep -n '^## CI' README.md` finds it; the existing README commands are unchanged (`git diff README.md` shows only additions). Add one line to `check-ci.sh` for this if the script is committed.

## Step 5: Final local verification and report

- Run `sh .github/scripts/check-ci.sh`, the YAML parse, and `actionlint` if available. Run `git diff --stat` to confirm only `.github/` and `README.md` changed (no Nix code, `flake.lock` untouched: spec "Out of scope").
- Run `mise install` only if a tool file has appeared; none exists. Do not claim any Nix build or evaluation.
- Final answer must say: Nix is not declared and not available, so no build was run; action versions and inputs are verified or not (say which); the first PR run is the real validation.

## Step 6: Validation on the first PR run (maintainer or follow-up, not doable in the sandbox)

Checklist from `design.md` "Testing":
1. Three checks appear: `flake-check`, `build (home)`, `build (framework13)`.
2. A second push to the PR cancels the first run (Scenario 9).
3. After the first `main` run, a later run shows a cache restore hit (relaxed Scenario 6).
4. No secret other than `GITHUB_TOKEN` is used (Scenario 5), including on a fork PR.
5. The disk does not run out. If disk or time fails, apply the fallback from `design.md` (replace the build step with `nix eval --raw '...toplevel.drvPath'`, drop the cache step); a one-line change.
6. If a host fails because of existing breakage, that is a finding about the config, not a CI bug.

## Risks and order

- Riskiest: Step 3 (unverified action inputs, disk and time on a free runner). It comes right after the skeleton, and the checks are written before it.
- Open questions in `design.md` (build vs evaluate only, Cachix, scheduled run) are not blocking: the plan follows the design defaults (build, Actions cache, no schedule). A schedule would be a two-line addition to `on:` if requested.
