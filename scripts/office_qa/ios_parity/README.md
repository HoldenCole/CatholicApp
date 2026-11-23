# iOS / Android parity

The two apps carry the same data and two hand-mirrored engines
(`OfficeRubrics`, `OfficeAssembler`, `OfficeFrame`, `ContentStore` in Kotlin
and Swift). This directory checks that they produce the same Office and the
same Mass for every day, by running the real iOS data layer on Linux.

`build.sh OUT_DIR` compiles `Introibo/Data`, `Introibo/Liturgical` and
`Introibo/Storage/Settings.swift` with a Swift toolchain for Linux
(swift.org, any 6.x), against a tiny stand-in for SwiftUI (`stub/`) and for
the one design type the data layer uses (`shims.swift`), plus `main.swift`,
which writes the same JSON as the Android `OfficeJsonDump` test does with
`OFFICE_JSON_FULL=1`: every part of every hour with all its fields, and the
day's Mass proper.

    # Android side
    cd android && OFFICE_JSON_FULL=1 OFFICE_JSON_DIR=/tmp/appqa \
      OFFICE_JSON_START=2025-11-30 OFFICE_JSON_END=2026-11-28 \
      gradle :app:testDebugUnitTest --tests '*OfficeJsonDump*' --rerun
    # iOS side
    scripts/office_qa/ios_parity/build.sh /tmp/iosbuild
    cd /tmp/iosbuild && LD_LIBRARY_PATH=/tmp/iosbuild/stub:$TOOLCHAIN/usr/lib/swift/linux \
      OFFICE_JSON_DIR=/tmp/iosqa OFFICE_JSON_START=2025-11-30 OFFICE_JSON_END=2026-11-28 ./harness
    # diff
    python3 scripts/office_qa/ios_parity/diff_parity.py --android /tmp/appqa --ios /tmp/iosqa

`OFFICE_JSON_LANG=es` (or `fr`, or any other vernacular's code) on both
sides compares that language's office and Mass; the harness applies a
language the pickers do not offer yet straight to the store, as the Android
test does.
`OFFICE_JSON_RITES` narrows the rites. Zero differences is the bar; any
difference is a bug in one of the mirrors (the first run found the Swift
`ownedKey` missing the DO-script keys, which printed a raw script at Easter
Sunday Vespers).
