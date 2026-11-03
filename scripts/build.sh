#!/bin/sh
# Generate the Xcode project and build Barkeeper (Debug). Usage: scripts/build.sh [--run]
set -e
cd "$(dirname "$0")/.."
xcodegen generate --quiet
xcodebuild -project Barkeeper.xcodeproj -scheme Barkeeper -configuration Debug \
  -derivedDataPath build build > build/xcodebuild.log 2>&1 || { grep -E ": error:" build/xcodebuild.log | sort -u; echo "BUILD FAILED"; exit 1; }
grep -E "\.swift:[0-9]+:[0-9]+: warning:" build/xcodebuild.log | sort -u || true
echo "BUILD SUCCEEDED"
if [ "$1" = "--run" ]; then
  pkill -x Barkeeper || true
  open build/Build/Products/Debug/Barkeeper.app
fi
