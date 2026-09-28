---
name: are-you-here
description: Use when the user makes an action conditional on whether they are at the laptop — "if I'm not here", "if I'm away", "if I'm at my desk", "only if I'm around", "when I'm back" — e.g. "if I'm not here commit without signing", "if I'm away skip the confirmation", "if I'm here ask me first".
---

# are-you-here

## Overview

A webcam presence check. Run it at the moment the condition matters, not at the start of the task, because the user may walk away mid-task.

```sh
sh <this skill's directory>/are-you-here.sh -q
```

| Exit | Meaning | Do |
|------|---------|----|
| 0 | person in front of the camera | take the "here" branch |
| 1 | nobody there | take the "not here" branch |
| 2 | error (no camera, camera permission denied, build failed) | show the stderr, take the "not here" branch if the user named one, otherwise ask |

It takes about 1–4s. `-t SECONDS` changes how long it looks (default 3), and `-v` logs each frame. The first run compiles `are-you-here.swift` with `swiftc` (Xcode Command Line Tools) and caches the binary, so it takes about 15s. macOS only.

## Rules

- Check right before the conditional action. Re-check for each separate conditional action in a long task.
- Say which branch you took and why, e.g. "are-you-here: absent → committing without signing".
- The check only picks the branch. Everything else the user asked for still happens on both branches.

## Common conditional actions

| User says | Here (0) | Not here (1) |
|-----------|----------|--------------|
| "if I'm not here commit without sign" | normal `git commit` (GPG-signed, pinentry prompts the user) | `git commit --no-gpg-sign ...` |
| "if I'm away don't wait for me" | ask / wait for confirmation as usual | continue with the default choice and note it in the summary |
| "if I'm here, ping me" | notify (e.g. `say` or `osascript -e 'display notification ...'`) | skip the notification |

GPG signing (`commit.gpgsign=true`) needs a passphrase from pinentry. With nobody at the keyboard, a signed commit hangs until it times out, so `--no-gpg-sign` is the "not here" path. Signing can be fixed up later with `git rebase --exec 'git commit --amend --no-edit -S' <base>` (use `--root` in place of `<base>` if the unsigned commits go back to the first commit). Mention that in the summary when you made unsigned commits.
