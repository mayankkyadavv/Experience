#!/bin/sh
# Runs the package tests. With only the Command Line Tools installed (no Xcode), Swift Testing
# lives outside the default search paths, so point the compiler and linker at it.
set -e
cd "$(dirname "$0")"
if xcode-select -p | grep -q CommandLineTools; then
  F=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
  L=/Library/Developer/CommandLineTools/Library/Developer/usr/lib
  exec swift test -Xswiftc -F -Xswiftc "$F" -Xlinker -F -Xlinker "$F" -Xlinker -rpath -Xlinker "$F" -Xlinker -rpath -Xlinker "$L" "$@"
fi
exec swift test "$@"
