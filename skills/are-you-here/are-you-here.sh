#!/bin/sh
# Runs are-you-here, compiling are-you-here.swift on first use.
# The binary is cached per source hash, so edits to the source trigger a rebuild.
# Arguments are passed through: sh are-you-here.sh [-t SECONDS] [-q] [-v]
set -e

dir=$(cd "$(dirname "$0")" && pwd)
src="$dir/are-you-here.swift"
hash=$(shasum "$src" | cut -c1-12)
cache="${XDG_CACHE_HOME:-$HOME/.cache}/are-you-here/$hash"
bin="$cache/are-you-here"

if [ ! -x "$bin" ]; then
  if ! command -v swiftc >/dev/null 2>&1; then
    echo "are-you-here: swiftc not found; install the Xcode Command Line Tools: xcode-select --install" >&2
    exit 2
  fi
  mkdir -p "$cache"
  # The default SDK can be newer than the installed compiler, so fall back
  # through the installed SDKs, newest first.
  if ! swiftc -O "$src" -o "$bin" 2>/dev/null; then
    built=
    for sdk in $(ls -dr /Library/Developer/CommandLineTools/SDKs/MacOSX[0-9]*.sdk 2>/dev/null); do
      if swiftc -O -sdk "$sdk" "$src" -o "$bin" 2>/dev/null; then built=1; break; fi
    done
    if [ -z "$built" ]; then
      echo "are-you-here: build failed; see errors with: swiftc \"$src\" -o /dev/null" >&2
      exit 2
    fi
  fi
fi

exec "$bin" "$@"
