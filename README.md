# NixOS config

Files used to complete the global `configuration.nix`.

## Emacs

### Markdown

If there is any issue in preview mode like bin not found you can use an explicit one like this

```Lisp
(custom-set-variables
 '(markdown-command "/home/bhoudebert/.nix-profile/bin/pandoc")
```

## Slack issue

It is possible that slack does not open any link from browser, I found that launching slack with `slack --enable-features=UseOzonePlatform,WebRTCPipeWireCapturer` plus `firefox` solve the issue.  
