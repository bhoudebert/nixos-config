{ pkgs, ... }:

let
  # Reuse a packaged wallpaper rather than managing a local asset.
  wallpaper = "${pkgs.nixos-artwork.wallpapers.simple-dark-gray.gnomeFilePath}";
in
{
  home-manager.users.bhoudebert = {
    # Main Hyprland compositor configuration: binds, layout, startup apps.
    xdg.configFile."hypr/hyprland.conf".text = ''
      monitor=,preferred,auto,1

      exec-once = waybar
      exec-once = mako
      exec-once = hyprpaper
      exec-once = nm-applet --indicator

      env = XCURSOR_SIZE,24
      env = NIXOS_OZONE_WL,1

      input {
        kb_layout = us
        kb_variant = intl
        follow_mouse = 1
        touchpad {
          natural_scroll = false
        }
        sensitivity = 0
      }

      general {
        gaps_in = 6
        gaps_out = 12
        border_size = 2
        layout = dwindle
        resize_on_border = true
      }

      decoration {
        rounding = 8
        blur {
          enabled = true
          size = 6
          passes = 2
        }
      }

      animations {
        enabled = true
      }

      dwindle {
        preserve_split = true
      }

      misc {
        disable_hyprland_logo = true
      }

      $mod = SUPER
      $terminal = kitty
      $menu = wofi --show drun
      $browser = librewolf
      $files = dolphin

      bind = $mod, RETURN, exec, $terminal
      bind = $mod, D, exec, $menu
      bind = $mod, B, exec, $browser
      bind = $mod, E, exec, $files
      bind = ALT, TAB, cyclenext
      bind = ALT SHIFT, TAB, cyclenext, prev
      bind = $mod SHIFT, Q, killactive
      bind = $mod SHIFT, E, exit
      bind = $mod, F, fullscreen, 1
      bind = $mod, V, togglefloating
      bind = $mod, P, pseudo
      bind = $mod, T, togglesplit

      bind = $mod, H, movefocus, l
      bind = $mod, L, movefocus, r
      bind = $mod, K, movefocus, u
      bind = $mod, J, movefocus, d

      bind = $mod SHIFT, H, movewindow, l
      bind = $mod SHIFT, L, movewindow, r
      bind = $mod SHIFT, K, movewindow, u
      bind = $mod SHIFT, J, movewindow, d
      bind = $mod CTRL, H, resizeactive, -80 0
      bind = $mod CTRL, L, resizeactive, 80 0
      bind = $mod CTRL, K, resizeactive, 0 -80
      bind = $mod CTRL, J, resizeactive, 0 80
      bind = $mod, comma, movecurrentworkspacetomonitor, l
      bind = $mod, period, movecurrentworkspacetomonitor, r
      bind = $mod SHIFT, comma, focusmonitor, l
      bind = $mod SHIFT, period, focusmonitor, r

      bind = $mod, 1, workspace, 1
      bind = $mod, 2, workspace, 2
      bind = $mod, 3, workspace, 3
      bind = $mod, 4, workspace, 4
      bind = $mod, 5, workspace, 5
      bind = $mod SHIFT, 1, movetoworkspace, 1
      bind = $mod SHIFT, 2, movetoworkspace, 2
      bind = $mod SHIFT, 3, movetoworkspace, 3
      bind = $mod SHIFT, 4, movetoworkspace, 4
      bind = $mod SHIFT, 5, movetoworkspace, 5

      bindel = ,XF86AudioRaiseVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+
      bindel = ,XF86AudioLowerVolume, exec, wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
      bindel = ,XF86MonBrightnessUp, exec, brightnessctl set +10%
      bindel = ,XF86MonBrightnessDown, exec, brightnessctl set 10%-
      bindl = ,XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
      bindl = ,XF86AudioPlay, exec, playerctl play-pause
      bindl = ,XF86AudioNext, exec, playerctl next
      bindl = ,XF86AudioPrev, exec, playerctl previous
      bind = ,Print, exec, grim -g "$(slurp)" - | wl-copy

      windowrule {
        name = float-pavucontrol
        match:class = ^(pavucontrol)$
        float = yes
      }

      windowrule {
        name = float-nm-connection-editor
        match:class = ^(nm-connection-editor)$
        float = yes
      }
    '';

    # Wallpaper daemon configuration.
    xdg.configFile."hypr/hyprpaper.conf".text = ''
      preload = ${wallpaper}
      wallpaper = ,${wallpaper}
      splash = false
    '';

    # Top bar layout and widget config.
    xdg.configFile."waybar/config".text = ''
      [{
        "layer": "top",
        "position": "top",
        "height": 34,
        "spacing": 8,
        "modules-left": ["hyprland/workspaces", "hyprland/window"],
        "modules-center": ["clock"],
        "modules-right": ["network", "pulseaudio", "backlight", "battery", "tray"],
        "clock": {
          "format": "{:%a %d %b  %H:%M}"
        },
        "network": {
          "format-wifi": "wifi {signalStrength}%",
          "format-ethernet": "eth",
          "format-disconnected": "offline",
          "tooltip-format": "{ifname} via {gwaddr}"
        },
        "pulseaudio": {
          "format": "vol {volume}%",
          "format-muted": "mute"
        },
        "backlight": {
          "format": "light {percent}%"
        },
        "battery": {
          "format": "bat {capacity}%",
          "format-charging": "chg {capacity}%"
        },
        "tray": {
          "spacing": 10
        }
      }]
    '';

    # Top bar theme.
    xdg.configFile."waybar/style.css".text = ''
      * {
        font-family: "JetBrainsMono", monospace;
        font-size: 13px;
      }

      window#waybar {
        background: rgba(20, 20, 24, 0.85);
        color: #f5f5f5;
      }

      #workspaces button {
        color: #d0d0d0;
        padding: 0 8px;
      }

      #workspaces button.active {
        color: #ffffff;
        background: #3a6ea5;
      }

      #clock,
      #network,
      #pulseaudio,
      #backlight,
      #battery,
      #tray,
      #window {
        margin: 6px 0;
        padding: 0 10px;
      }
    '';

    # App launcher settings.
    xdg.configFile."wofi/config".text = ''
      width=720
      height=420
      prompt=Run
      show=drun
      allow_markup=true
      term=kitty
      normal_window=true
      image_size=24
      gtk_dark=true
    '';

    # App launcher theme.
    xdg.configFile."wofi/style.css".text = ''
      window {
        margin: 0;
        border: 2px solid #3a6ea5;
        background-color: #111318;
        color: #f5f5f5;
      }

      #input {
        margin: 12px;
        padding: 10px 12px;
        border: none;
        background-color: #1b1f27;
        color: #f5f5f5;
      }

      #entry {
        padding: 10px 12px;
      }

      #entry:selected {
        background-color: #3a6ea5;
      }
    '';

    # Notification daemon styling.
    xdg.configFile."mako/config".text = ''
      anchor=top-right
      default-timeout=5000
      background-color=#111318dd
      border-color=#3a6ea5ff
      text-color=#f5f5f5ff
      width=360
      height=120
      margin=16
      padding=14
      border-size=2
      border-radius=8
      icons=1
      max-visible=5
    '';
  };
}
