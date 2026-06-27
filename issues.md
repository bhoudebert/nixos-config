# Issues log

This file is a short incident log: what broke, what evidence was collected,
what workaround was confirmed, and what to revisit later.

## Desktop memory pressure and screenshot instability

Date observed: 2026-06-16
Status: mitigation added; needs activation with `nixos-rebuild switch`.

## Symptom

The desktop had become intermittently unstable over several weeks:

- screenshots sometimes turned the desktop black
- Firefox sometimes used roughly 20-28 GiB of RAM
- the system occasionally became sluggish or poorly responsive
- games such as Dying Light: The Beast did not show the same issue

## Evidence collected

The current boot was clean after a reboot, but persistent journal history still
showed the previous incidents:

- no kernel OOM kills were logged over the checked window
- no swap or zram was configured, so memory spikes had no pressure buffer
- `app-firefox` systemd scopes recorded memory peaks of 18.4G, 20.6G, 23.4G,
  and 28.4G
- a Firefox content process crashed with an internal `NS_ABORT_OOM` stack
- KWin/Plasma Wayland repeatedly logged `atomic commit failed: Permission denied`
  and `Atomic modeset test failed! Permission denied`
- the lock screen logged `The Wayland connection broke. Did the Wayland compositor die?`

This points at two overlapping problems rather than one root cause: real browser
memory spikes, plus a Plasma Wayland/NVIDIA compositor failure path around
screen capture or display state changes.

## Mitigation added

`modules/nixos/core/memory.nix` now enables zram swap and user-slice oomd:

- zram swap with `zstd`, sized at 50% of RAM
- `vm.swappiness = 180` and `vm.page-cluster = 0` for zram-friendly swapping
- `systemd.oomd.enableUserSlices = true` so user workloads are watched under
  memory pressure

The NixOS toplevel build succeeded, but activation did not run from Codex
because `sudo` needed an interactive password prompt.

## Plasma Wayland shell missing after sleep resume

Date observed: 2026-04-19
Status: workaround confirmed; root cause probable but not fixed. Staying on Wayland.

## Symptom

After waking the PC from sleep, the Plasma desktop shell was effectively gone:

- no wallpaper
- no taskbar / panel
- no normal desktop shell UI

This looked like "Explorer is missing", but the problem was not a Windows-style shell process issue. The desktop session itself was still partly alive.

## Evidence collected

The user journal from the broken session pointed at a graphics resume failure in the Wayland compositor / shell path:

- `kwin_wayland`: atomic commit failed with `Permission denied`
- `kwin_wayland`: `Atomic modeset test failed! Permission denied`
- `kwin_wayland`: `Applying output configuration failed!`
- `plasmashell`: `QRhiGles2: Context is lost`
- `plasmashell`: `Graphics device lost`
- `plasmashell`: repeated `eglError: 0x3006` and `Failed to start frame`

That strongly suggests a suspend/resume graphics issue on the NVIDIA + Plasma Wayland stack, not just a panel applet crash.

## Resolution used

The working recovery was:

```bash
systemctl --user restart plasma-plasmashell.service
```

This restored the wallpaper, taskbar, and normal Plasma shell UI without requiring a logout or reboot.

## Notes

- Current preference is to stay on Wayland; switching to X11 is not the chosen workaround.
- Existing NixOS config already has NVIDIA enabled with modesetting, but this incident was resolved at the session level by restarting `plasmashell`.
- If the issue starts recurring often, the next investigation should focus on NVIDIA suspend/resume handling while keeping Wayland.
