#!/bin/zsh
# Rebuilds ambient/*.m4a from the long source recordings in sounds/ (not kept in git: ~1 GB).
# Each loop is 45 s cut from mid-file, crossfaded end-to-start over 3 s so it loops seamlessly,
# leveled (fires get a peak limiter for their crackles), then encoded as 96 kbps AAC (~550 KB).
# Usage: tools/make-ambient.sh   (needs Xcode command line tools for swiftc; afconvert ships with macOS)
set -e
cd "$(dirname "$0")/.."
TMP=$(mktemp -d)
swiftc -O tools/makeloop.swift -o "$TMP/makeloop"
loop() {  # <source> <start sec> <target RMS dB> <name>
  "$TMP/makeloop" "sounds/$1" "$2" 45 3 "$3" "$TMP/$4.wav"
  afconvert -f m4af -d aac@44100 -b 96000 -q 127 "$TMP/$4.wav" "ambient/$4.m4a"
}
mkdir -p ambient
loop "3 Hours Logs Burning in Fireplace!.m4a"  4000 -28 logs
loop "The Best Fireplace Video (3 hours).m4a"  5000 -28 fireplace
loop "Babbling-Brook_sound-bath-10min.wav"      200 -24 brook
loop "Coastal-Rain_PVE-2019-12-4.wav"           600 -24 rain
loop "file0050-Crickets.wav"                    300 -24 crickets
rm -rf "$TMP"
ls -la ambient
