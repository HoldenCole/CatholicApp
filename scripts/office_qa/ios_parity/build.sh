#!/bin/bash
# Build the iOS data layer and the dump harness on Linux (needs a Swift
# toolchain on PATH; see README.md). Usage: build.sh OUT_DIR
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
ROOT="$(cd "$HERE/../../.." && pwd)"
OUT="${1:?usage: build.sh OUT_DIR}"
mkdir -p "$OUT/stub"
(cd "$OUT/stub" && swiftc -emit-module -emit-library -module-name SwiftUI "$HERE/stub/SwiftUI.swift" -o libSwiftUI.so)
cd "$ROOT"
FILES="$(ls Introibo/Data/*.swift | grep -v 'WidgetSnapshotWriter\|DailyPrayer') \
 $(ls Introibo/Data/Links/*.swift Introibo/Data/Search/*.swift | grep -v DeepLinkRouter) \
 $(ls Introibo/Liturgical/*.swift) Introibo/Storage/Settings.swift"
swiftc -O -I "$OUT/stub" -L "$OUT/stub" -lSwiftUI -module-name Harness $FILES "$HERE/shims.swift" "$HERE/main.swift" -o "$OUT/harness"
# Bundle.main resolves resources beside the executable on Linux.
ln -sf "$ROOT"/Introibo/Resources/*.json "$OUT/"
echo "built $OUT/harness — run with LD_LIBRARY_PATH=$OUT/stub:<toolchain>/usr/lib/swift/linux"
