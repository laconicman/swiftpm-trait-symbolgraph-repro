#!/usr/bin/env bash
#
# Regression harness for: symbol-graph extraction downloads binary artifacts belonging to
# trait-gated dependencies that are disabled.
#
#   exit 0  -> every expectation met (the bug is FIXED on this toolchain)
#   exit 1  -> at least one expectation violated (the bug is PRESENT)
#
# No network access is required or made: the binaryTarget URL is unreachable by design, so a
# download *attempt* is the signal. Runs are isolated via --cache-path/--scratch-path, so this
# never touches your real SwiftPM cache.
set -uo pipefail
cd "$(dirname "$0")/App"

CACHE=$(mktemp -d); SCRATCH=$(mktemp -d)
trap 'rm -rf "$CACHE" "$SCRATCH"' EXIT
ISO=(--cache-path "$CACHE" --scratch-path "$SCRATCH")
MARKER='example.invalid'
fail=0

echo "toolchain: $(swift --version 2>/dev/null | head -1)"
echo

# run <expectation: yes|no> <label> <command...>
#   yes = a download attempt is expected   no = no download attempt should occur
run() {
  local expect=$1 label=$2; shift 2
  local out; out=$("$@" 2>&1)
  local got=no; grep -qF "$MARKER" <<<"$out" && got=yes
  if [ "$got" = "$expect" ]; then
    printf '  %-52s %s\n' "$label" "ok"
  else
    printf '  %-52s %s\n' "$label" "MISMATCH (expected download=$expect, got $got)"
    fail=1
  fi
}

echo "positive control — trait ENABLED, a download attempt is correct:"
run yes "swift build --traits Heavy"                 swift build "${ISO[@]}" --traits Heavy

echo
echo "trait DISABLED — no download attempt should ever occur:"
run no  "swift build"                                swift build "${ISO[@]}"
run no  "swift package resolve"                      swift package "${ISO[@]}" resolve
run no  "swift package show-dependencies"            swift package "${ISO[@]}" show-dependencies
run no  "swift package dump-symbol-graph"            swift package "${ISO[@]}" dump-symbol-graph
run no  "swift package --disable-default-traits (dsg)"   swift package "${ISO[@]}" --disable-default-traits dump-symbol-graph
run no  "plugin -> packageManager.getSymbolGraph"    swift package "${ISO[@]}" plugin --allow-writing-to-package-directory probe-symbol-graph
run no  "plugin -> packageManager.build  (control)"  swift package "${ISO[@]}" plugin --allow-writing-to-package-directory probe-build

echo
if [ "$fail" -eq 0 ]; then
  echo "RESULT: fixed — no trait-gated artifact was requested."
else
  echo "RESULT: present — a disabled trait's binary artifact was requested."
fi
exit $fail
