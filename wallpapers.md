# Animated wallpapers

The NixOS configuration installs the reusable software, but wallpaper videos are
personal media and are deliberately not stored in this repository.

The `home` host installs:

- Smart Video Wallpaper Reborn for Plasma 6
- `ffmpeg` for inspecting and converting videos
- `mpvpaper` for optional use from a Hyprland session

Keep local videos in a directory such as:

```bash
mkdir -p ~/Videos/Wallpapers
```

## Prepare a video

Smart Video Wallpaper Reborn can open common video formats directly. If a file
does not play smoothly, convert it to a broadly compatible, silent H.264 MP4:

```bash
ffmpeg -i input-video.mp4 \
  -map 0:v:0 -an \
  -c:v libx264 -preset medium -crf 20 \
  -pix_fmt yuv420p -movflags +faststart \
  ~/Videos/Wallpapers/wallpaper.mp4
```

This command converts an existing animation. It does not create independent
cloud, fog, or character motion from a still image; producing that kind of
animation requires a video compositor, a 3D tool, or generated source footage.

## Configure Plasma manually

1. Right-click the desktop and open **Desktop and Wallpaper**.
2. Select **Smart Video Wallpaper Reborn** as the wallpaper type.
3. Add a video from `~/Videos/Wallpapers`.
4. Choose the desired fill, blur, pause, and mute settings.
5. Select **Apply**.

The choice remains Plasma-managed state. Nix installs the plugin but does not
force a particular wallpaper or modify the Plasma desktop layout.

## Use a video in Hyprland

Hyprland retains its static declarative fallback. To try a local video for the
current session, stop `hyprpaper` and start `mpvpaper`:

```bash
pkill hyprpaper
mpvpaper -p -a max \
  -o "no-audio loop-file=inf hwdec=auto" \
  "*" ~/Videos/Wallpapers/wallpaper.mp4
```

This command is intentionally not part of the declarative startup configuration
because the referenced media is local and may not exist on every machine.
