# S/PDIF silent-output issue — NixOS

Date of investigation: 2026-04-18
Status: fixed by reboot; root cause probable but unconfirmed; mitigation proposed.

This note is intentionally detailed because it documents a hardware-specific
failure mode and the exact evidence gathered while the issue was live.

## Symptom

Intermittent loss of audio through the motherboard's rear-panel optical (TOSLINK) S/PDIF output. Chain is:

    motherboard optical jack → TOSLINK cable → Yamaha YHT1993 AMP → KEF bookshelf speakers

When it dies:
- All software layers *appear* fine: PipeWire sink present, unmuted, volume normal, default sink.
- Kernel-level PCM goes to `RUNNING` state with `hw_ptr`/`appl_ptr` advancing — bytes are flowing into the audio chip.
- Red laser at the TOSLINK transmitter is visible — optical hardware is firing.
- AMP receives nothing, shows no lock indicator.
- On Windows the user fixes the same symptom with a `.bat` that restarts the audio services; on Linux a userspace restart didn't help.

## Hardware / topology

- Host: NixOS, linux 6.18.22, PipeWire 1.6.2 + WirePlumber 0.5.14.
- The "S/PDIF device" is not a USB DAC — it is the **motherboard's onboard audio codec** (ASRock), but the chip is wired internally over USB. Linux therefore labels it `USB Audio` even though the optical jack is on the rear I/O panel. This is common on modern ASRock / ASUS / MSI boards.
- Identification:
  - ALSA card 5, name `Audio`, description `Generic USB Audio at usb-0000:13:00.0-8, high speed`
  - USB VID:PID `26ce:0a08` (vendor 26ce = ASRock)
  - USB sysfs path: `/sys/bus/usb/devices/3-8`
  - UCM profile in use: `HiFi: SPDIF: sink`
  - Default sink node name: `alsa_output.usb-Generic_USB_Audio-00.HiFi__SPDIF__sink`
  - PCM device for S/PDIF: `hw:5,3` (card 5, device 3, i.e. `/proc/asound/card5/pcm3p`)
  - Other outputs on the same chip: analog Speakers (`hw:5,2`), Front Headphones (`hw:5,1`), plus `hw:5,0` duplex.
- Also in the system (not involved in this issue): NVIDIA GB203 HDMI audio, Radeon HDMI audio, Blue Yeti X USB mic, Logitech StreamCam.

## Diagnostics run (summary)

All the following were tried with **no effect** on the audible symptom:

1. `systemctl --user restart wireplumber pipewire-pulse pipewire` — services came back, sink came back, but no sound.
2. `systemctl --user stop ... (sockets too) && sudo modprobe -r snd_usb_audio && sudo modprobe snd_usb_audio` — was attempted but `modprobe -r` failed with "Module is in use" (pipewire sockets were still holding refs); we brought PipeWire back up without reloading the module.
3. Card-profile cycle `wpctl set-profile <id> 0 && sleep 1 && wpctl set-profile <id> 1` — device fully re-enumerated (sink ID changed), no audible change.
4. Soft USB "re-plug" at the kernel level:
   ```
   echo 0 | sudo tee /sys/bus/usb/devices/3-8/authorized
   sleep 2
   echo 1 | sudo tee /sys/bus/usb/devices/3-8/authorized
   ```
   — device re-enumerated, no audible change.
5. Switching to the `pro-audio` profile (index 4) to bypass UCM entirely and talk raw ALSA (`hw:5,3`) — sink switched, `pw-play --target=<raw-sink>` confirmed `state: RUNNING`, `S16_LE 48000 Hz stereo`, frames advancing, `pw-play` exited 0 — **but still no audible sound**. This ruled out UCM as the culprit.
6. Output differential diagnosis: played test tones to the same chip's analog Speakers (sink 84) and Headphones (sink 61) — user heard nothing, but those jacks aren't physically wired up so the test was inconclusive.
7. HDMI sanity check: HDMI audio to monitor speakers **worked**, confirming PipeWire's general output path is healthy — the fault is specific to the USB Audio chip's output stages.
8. Visible TOSLINK laser check: red light visible at the motherboard jack side (ambiguous — the LED is internal and can be always-on).
9. Mixer inspection via `nix-shell -p alsa-utils --run "amixer -c 5 contents"`:
   - No `IEC958 Playback Switch` control exists on this chip.
   - Three `PCM Playback Switch` controls: `numid=15` (index 0, Speakers), `numid=19` (index 1, Headphones), `numid=22` (index 2, S/PDIF).
   - In the broken state I **only captured the type line for these controls**, not the `: values=` line (my grep used `-A1` instead of `-A2`) — so I cannot prove what state they were in.

## Resolution

`sudo reboot` — sound returned immediately on login.

## What differs between broken and working state

Captured during the working post-reboot session:

- `PCM Playback Switch` (`numid=15`, Speakers):        `values=off`
- `PCM Playback Switch` (`numid=19` index 1, Headphones): `values=off`
- `PCM Playback Switch` (`numid=22` index 2, **S/PDIF**): `values=on` ← the one that matters
- PCM when playing: `access: MMAP_INTERLEAVED`, `format: S16_LE`, `rate: 48000`, `channels: 2`, `state: RUNNING` — identical to broken state.
- ALSA card ordering changed on this reboot (Yeti X moved from card 3 to card 0), but card 5 still holds the onboard audio chip — irrelevant to this issue.
- Stored default-sink name in WirePlumber config is now `alsa_output.usb-Generic_USB_Audio-00.pro-output-3` (a side-effect of the pro-audio experiment during debugging) — should be reset to the HiFi S/PDIF sink next time pro-audio isn't needed.

## Working hypothesis for the root cause

The ALSA mixer control `PCM Playback Switch` at `numid=22` (index 2, the S/PDIF enable for this chip) was toggled to **off** in the stuck state, and returned to its default **on** at boot. This would:

- Still allow PipeWire to open the PCM (no error reported).
- Still let the kernel drive the USB isochronous endpoint (so PCM reports `RUNNING` with frames advancing).
- Still leave the optical transmitter idle-firing (red light visible).
- But block actual audio data from reaching the S/PDIF encoder → AMP sees no valid audio frames → silence.

This is consistent with every observation we captured, and with the Windows-side behavior where a driver re-init unsticks it (reinitializing the driver resets mixer controls to defaults).

**It is not proven.** Other candidates, in decreasing order of plausibility:
- A chip-internal DSP/clock stall that only a full chip power-cycle resolves (reboot works because +5V_AUX is cut; `reboot` from a running kernel may or may not — worth checking).
- A kernel-driver state (`snd-usb-audio` quirks) that requires a full module reload (we never successfully executed `rmmod`).
- WirePlumber persisting a mute state that only gets cleared when the saved-state files are re-read from scratch (unlikely — pro-audio bypass ruled out most PipeWire-side mute state).

## Verification plan when it next fails

**Run this first, before any other intervention**, to confirm or rule out the hypothesis:

```bash
nix-shell -p alsa-utils --run "amixer -c 5 contents" \
  | grep -A2 "PCM Playback Switch'"
```

Look at the `: values=` line for `index=2`:
- If `values=off` → **hypothesis confirmed**. Fix with:
  ```bash
  nix-shell -p alsa-utils --run "amixer -c 5 cset numid=22 on"
  ```
- If `values=on` → hypothesis wrong; cause is deeper. Capture state and escalate to full module reload:
  ```bash
  wpctl status > /tmp/broken-wpctl.txt
  cat /proc/asound/card5/pcm3p/sub0/status > /tmp/broken-pcm3p.txt
  dmesg | grep -i usb | tail -30 > /tmp/broken-dmesg.txt
  journalctl --user -u pipewire --since "20 min ago" > /tmp/broken-pw.txt

  systemctl --user stop pipewire pipewire-pulse wireplumber pipewire.socket pipewire-pulse.socket
  sleep 2
  sudo modprobe -r snd_usb_audio
  sudo modprobe snd_usb_audio
  sleep 2
  systemctl --user start pipewire
  ```
  If **that** also fails, only a full `poweroff` (not `reboot`) with ~20 s wait for the +5V_AUX rail to drain will reset the chip.

## Proposed mitigation

If recurrence confirms the mixer-mute hypothesis, enforce `numid=22 on` automatically:

1. Store the correct mixer state once with `alsactl`:
   ```bash
   sudo nix-shell -p alsa-utils --run "alsactl --file /etc/asound.state store 5"
   ```
2. Re-apply it on resume-from-sleep via a small systemd unit (example below; add to NixOS config):
   ```nix
   systemd.services."fix-spdif-unmute" = {
     description = "Re-assert S/PDIF unmute on resume (ASRock USB Audio 26ce:0a08)";
     wantedBy = [ "sleep.target" ];
     after = [ "suspend.target" "hibernate.target" "hybrid-sleep.target" ];
     serviceConfig.Type = "oneshot";
     script = ''
       ${pkgs.alsa-utils}/bin/amixer -c 5 cset numid=22 on || true
     '';
   };
   ```
   (Only meaningful if the mute correlates with sleep/resume. If it happens at random times without a sleep event, a udev/systemd-timer approach would be needed instead — or simpler: a user-invokable `fix-audio` shell function.)

3. Lighter alternative — add a `fix-audio` zsh function the user can type when the symptom appears:
   ```zsh
   fix-audio() {
     nix-shell -p alsa-utils --run "amixer -c 5 cset numid=22 on" >/dev/null
     echo "S/PDIF unmute re-asserted."
   }
   ```

## Useful commands for this box (reference)

- `pactl`, `fuser`, `aplay` are **not** in PATH by default on this NixOS install. Use:
  - `wpctl status`, `wpctl inspect <id>`, `wpctl get-volume`, `wpctl set-profile`, `wpctl set-default`
  - `pw-cli ls Node`, `pw-cli enum-params <id> EnumProfile`, `pw-dump`
  - `pw-play --target=<id> --volume=0.5 <file>`
  - `cat /proc/asound/card5/pcm3p/sub0/{status,hw_params}` — kernel-side ground truth
  - `nix-shell -p alsa-utils --run "amixer -c 5 contents"` — mixer state
  - `lsof /dev/snd/*` — who holds ALSA devices (substitute for `fuser`)
- Test wav available on disk: `/nix/store/zcf2i5b3slql2zvryxb03bi078y0p7bv-speech-dispatcher-0.12.1/share/sounds/speech-dispatcher/test.wav`
