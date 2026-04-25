# Issues log

This file is a short incident log: what broke, what evidence was collected,
what workaround was confirmed, and what to revisit later.

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
