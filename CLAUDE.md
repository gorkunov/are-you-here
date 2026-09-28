# are-you-here

A macOS webcam presence check, shipped as an agent skill installable with
`npx skills add gorkunov/are-you-here`.

## Layout

Everything the skill needs lives in `skills/are-you-here/`, because the skills installer copies
only that folder:

- `SKILL.md`: the skill. Reference files next to it relative to the skill's directory, never by
  absolute path.
- `are-you-here.swift`: the detector (AVFoundation camera + Vision face / upper-body detection).
- `are-you-here.sh`: the entry point. It compiles the Swift file on first use into
  `~/.cache/are-you-here/<source hash>/` and then runs the binary with the arguments it was given.

## Constraints

- Zero dependencies: only frameworks built into macOS, and `swiftc` from the Xcode Command Line
  Tools. No Swift packages, Homebrew or npm.
- The exit codes are the contract the skill relies on: `0` present, `1` absent, `2` error. Errors
  go to stderr, and the result (`present`/`absent`) goes to stdout unless `-q` is passed.
- Invoke the wrapper as `sh are-you-here.sh`, not by bare path, since installers may drop the
  executable bit.
- The default SDK can be newer than the installed compiler ("this SDK is not supported by the
  compiler"). The wrapper falls back through the installed SDKs, so keep that loop.
- Keep `SKILL.md` under about 500 words, and keep its `description` to trigger phrases only.

## Testing

There's no test suite. It needs a real camera:

```sh
rm -rf ~/.cache/are-you-here                 # force a rebuild
sh skills/are-you-here/are-you-here.sh -v    # sitting in front of it: "present", exit 0
sh skills/are-you-here/are-you-here.sh -v    # camera covered or away: "absent", exit 1
npx -y skills add . --list                   # installer still finds the skill
```

To test how an agent follows the skill without leaving the desk, copy `SKILL.md` somewhere, point
it at a stub script that exits `1`, and have a subagent follow it.
