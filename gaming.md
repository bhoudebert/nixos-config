# Gaming and benchmark stack (`gaming.nix`)

This machine's gaming and GPU benchmark setup is declared in
`home/gaming.nix`.

Apply changes with:

```bash
sudo nixos-rebuild switch --flake .#home
```

## What is installed and why

### Runtime and compatibility

- `steam`
  Main game launcher for native Linux titles and Proton-based Windows
  games.

- `proton-ge-bin`
  Extra Proton build for games that need newer fixes or different
  compatibility behavior than Valve's default Proton releases.

### Overlay and telemetry

- `mangohud`
  In-game overlay for FPS, frametime, CPU/GPU usage, clocks,
  temperatures, power draw, RAM, and VRAM. Use it when you want live
  telemetry while gaming or benchmarking.

### Benchmark orchestration

- `phoronix-test-suite`
  Benchmark runner and result manager. Use it when you want installed
  test profiles, repeated runs, result uploads, and comparisons on
  OpenBenchmarking.

- `vkmark` via Phoronix Test Suite
  Vulkan benchmark used through PTS, not through `pkgs.vkmark`.
  Good for Vulkan stack validation and synthetic GPU comparisons on
  Linux.

  Important note: `pkgs.vkmark` is intentionally not enabled here
  because that package previously broke the rebuild against newer Vulkan
  headers. The working path on this machine is the PTS-installed test.

### Native benchmark binaries

- `glmark2`
  Quick OpenGL benchmark and sanity check. Useful for validating that
  the graphics stack is functional, but not the best modern high-end GPU
  comparison tool.

- `unigine-superposition`
  Main native Linux GPU benchmark in this setup. Use this first when you
  want a heavier standalone benchmark with a more polished built-in test
  flow than `glmark2`.

- `unigine-heaven`
  Older but still recognizable UNIGINE benchmark. Useful as a legacy
  reference point, less useful for modern API-era comparisons.

- `unigine-valley`
  Another older UNIGINE benchmark. Fine as an extra data point, but not
  the first benchmark to reach for on a modern high-end GPU.

### Support tooling for PTS graphics tests

- `vulkan-tools`
  Diagnostics such as `vulkaninfo`. Use this to verify Vulkan before
  blaming a benchmark.

- `gcc`, `meson`, `ninja`, `pkg-config`, Vulkan/X11/Wayland/DRM headers
  and dev libraries
  These are present so PTS can build graphics benchmarks such as
  `vkmark` correctly on this machine.

## When to use which tool

- Use `mangohud` when you want live FPS and frametime data inside a real
  game or benchmark.
- Use `phoronix-test-suite benchmark vkmark` when you want a Vulkan-only
  synthetic benchmark and optional OpenBenchmarking uploads.
- Use `glmark2` when you want a fast OpenGL smoke test.
- Use `unigine-superposition` when you want the best native standalone
  GPU benchmark currently installed here.
- Use `unigine-heaven` or `unigine-valley` only when you want older
  historical reference points.

## Typical commands

```bash
# Overlay on any command
mangohud <command>

# Quick OpenGL benchmark
glmark2

# Vulkan benchmark through PTS
phoronix-test-suite benchmark vkmark

# Force PTS/vkmark to offer a specific resolution
OVERRIDE_VIDEO_MODES=5120x1440 phoronix-test-suite benchmark vkmark

# Native UNIGINE benchmarks
unigine-superposition
heaven
valley

# Vulkan diagnostics
vulkaninfo | less
```

## Practical guidance

- The connected displays on this machine are on the NVIDIA card, and the
  live OpenGL renderer is already the RTX 5080.
- If `Superposition` shows the AMD iGPU in its UI, treat that as a
  system-info quirk until proven otherwise. Verify the real renderer
  with `glxinfo -B`, `mangohud unigine-superposition`, or `nvidia-smi`
  while the benchmark is running.
- For `vkmark`, compare results only when the `vkmark` version,
  resolution, and present mode match.
- Keep one native-resolution run for your actual monitor and one common
  preset if you want easier public comparison.
- For Linux-native benchmarking, prefer `vkmark` and
  `unigine-superposition` over fighting `3DMark` through Proton.

## Verifying which GPU is really used

When an app's own UI reports the wrong adapter, trust the runtime checks
below instead.

### 1. Check the desktop OpenGL renderer

```bash
glxinfo -B
```

What matters:

- `OpenGL vendor string`
- `OpenGL renderer string`

On this machine, the correct result is NVIDIA / RTX 5080.

### 2. Check live overlay data inside the benchmark

```bash
mangohud unigine-superposition
```

What to watch:

- GPU utilization rising during the run
- NVIDIA clocks / power / VRAM changing under load

If MangoHud shows the NVIDIA GPU being exercised, that is stronger
evidence than the benchmark's own system-info label.

### 3. Check NVIDIA activity directly from the driver

```bash
watch -n1 nvidia-smi
```

What to watch:

- the benchmark process appearing in the process list
- GPU utilization increasing
- VRAM usage increasing while the benchmark is active

If `nvidia-smi` shows the benchmark process and the GPU load climbs, the
benchmark is using the RTX 5080 even if UNIGINE displays the AMD iGPU
name in its UI.
