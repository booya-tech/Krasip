#!/bin/zsh
# build-release.sh
# Krasip
# Builds a Release copy of Krasip.app into ./build, signed with your Apple Development certificate.

set -euo pipefail
cd "$(dirname "$0")/.."

xcodebuild \
  -project Krasip.xcodeproj \
  -scheme Krasip \
  -configuration Release \
  -derivedDataPath build/DerivedData \
  build | grep -E "error:|warning:|BUILD" || true

rm -rf build/Krasip.app
cp -R build/DerivedData/Build/Products/Release/Krasip.app build/Krasip.app
echo "Built: $(pwd)/build/Krasip.app"
echo "Drag it to /Applications, or run: open build/Krasip.app"
