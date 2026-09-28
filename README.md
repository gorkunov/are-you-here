# are-you-here

A webcam presence check for macOS, packaged as a skill for coding agents. It tells the agent whether
you're sitting at the laptop, so you can make instructions conditional on it:

```
commit this, and in case if I'm not here commit without sign
if I'm away don't wait for me, pick the default
if I'm here, ping me when the tests finish
```

## Install

```bash
npx skills add gorkunov/are-you-here
```

That works for Claude Code, Codex, Cursor, OpenCode and the other agents
[skills](https://github.com/vercel-labs/skills) supports; add `-g` to install it for every project.

It needs macOS and the Xcode Command Line Tools (`xcode-select --install`), which you already have
if `git` works. Nothing else: detection uses the built-in AVFoundation and Vision frameworks.

## How it works

The skill ships `are-you-here.swift` and a small wrapper. On first use the wrapper compiles it with
`swiftc` and caches the binary in `~/.cache/are-you-here/`. That takes about 15s, and later runs
take about a second. The check turns on the camera, skips a few frames while exposure settles, and
looks for a face or an upper body for up to 3 seconds.

The first run triggers the macOS camera permission prompt for your terminal app.

## Use it without an agent

```bash
sh skills/are-you-here/are-you-here.sh          # prints present/absent
sh skills/are-you-here/are-you-here.sh -q       # exit code only
sh skills/are-you-here/are-you-here.sh -t 5 -v  # look for 5s, log each frame
```

| Exit | Meaning           |
| ---- | ----------------- |
| 0    | someone is there  |
| 1    | nobody is there   |
| 2    | error (no camera, permission denied, build failed) |
