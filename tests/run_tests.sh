#!/bin/sh
#
# mbeep test suite.
#
# Drives the built binary end-to-end: exit codes, .wav output validity, and
# error handling. .wav generation runs with no audio device (file mode), so
# these tests pass on headless systems.
#
# Playback tests (which open the audio device) run only when MBEEP_PLAYBACK=1.
# In CI on Linux this is paired with ALSOFT_DRIVERS=null (openal-soft's headless
# backend) so the OpenAL path executes without sound hardware.
#
# Usage:
#   MBEEP=./mbeep tests/run_tests.sh
#   MBEEP_PLAYBACK=1 ALSOFT_DRIVERS=null tests/run_tests.sh

set -u

MBEEP="${MBEEP:-./mbeep}"
PASS=0
FAIL=0

WORK="$(mktemp -d "${TMPDIR:-/tmp}/mbeep-tests.XXXXXX")"
trap 'rm -rf "$WORK"' EXIT

ok()  { PASS=$((PASS + 1)); }
ko()  { FAIL=$((FAIL + 1)); printf 'FAIL: %s\n' "$1" >&2; }

# run_ok "description" cmd args...   -- expect exit 0
run_ok() {
    desc="$1"; shift
    if "$@" >/dev/null 2>&1; then ok "$desc"; else
        ko "$desc (expected exit 0, got $?)"
    fi
}

# run_fail "description" cmd args... -- expect non-zero exit
run_fail() {
    desc="$1"; shift
    if "$@" >/dev/null 2>&1; then
        ko "$desc (expected non-zero exit, got 0)"
    else
        ok "$desc"
    fi
}

# is_wav FILE -- true if FILE is a non-empty RIFF/WAVE file
is_wav() {
    [ -s "$1" ] || return 1
    [ "$(head -c 4 "$1")" = "RIFF" ] || return 1
    [ "$(dd if="$1" bs=1 skip=8 count=4 2>/dev/null)" = "WAVE" ] || return 1
    return 0
}

# gen_wav "description" out.wav cmd args... -- expect exit 0 AND valid wav
gen_wav() {
    desc="$1"; out="$2"; shift 2
    rm -f "$out"
    if "$@" >/dev/null 2>&1 && is_wav "$out"; then ok "$desc"; else
        ko "$desc (bad exit or invalid wav)"
    fi
}

# ---------------------------------------------------------------------------
# Informational output (all exit 0)
# ---------------------------------------------------------------------------
run_ok "--help"        "$MBEEP" --help
run_ok "-h"            "$MBEEP" -h
run_ok "--version"     "$MBEEP" --version
run_ok "-v"            "$MBEEP" -v
run_ok "--license"     "$MBEEP" --license
run_ok "--midi-help"   "$MBEEP" --midi-help
run_ok "--morse-help"  "$MBEEP" --morse-help
run_ok "--man-page"    "$MBEEP" --man-page
run_ok "--list-devices" "$MBEEP" --list-devices

# man-page output actually contains roff markup
if "$MBEEP" --man-page 2>/dev/null | grep -q '^\.TH mbeep'; then
    ok "man-page contains .TH"
else
    ko "man-page missing .TH header"
fi

# ---------------------------------------------------------------------------
# Tone generation (frequency / duration)
# ---------------------------------------------------------------------------
gen_wav "default tone"           "$WORK/t1.wav" "$MBEEP" -o "$WORK/t1.wav"
gen_wav "explicit freq/time"     "$WORK/t2.wav" "$MBEEP" -o "$WORK/t2.wav" -f 440 -t 50
gen_wav "gap + repeats"          "$WORK/t3.wav" "$MBEEP" -o "$WORK/t3.wav" -f 660 -t 30 -g 40 -r 3
gen_wav "--wav alias"            "$WORK/t4.wav" "$MBEEP" --wav "$WORK/t4.wav" -f 1000 -t 20
gen_wav "multiple -p segments"   "$WORK/t5.wav" "$MBEEP" -o "$WORK/t5.wav" -f 440 -t 20 -p -f 880 -t 20 -p
gen_wav "freq lower bound (20)"  "$WORK/t6.wav" "$MBEEP" -o "$WORK/t6.wav" -f 20 -t 10
gen_wav "freq upper bound"       "$WORK/t7.wav" "$MBEEP" -o "$WORK/t7.wav" -f 20000 -t 10

# ---------------------------------------------------------------------------
# MIDI notes
# ---------------------------------------------------------------------------
gen_wav "named notes"            "$WORK/m1.wav" "$MBEEP" -o "$WORK/m1.wav" -b 120 -m "C4q D4q E4q"
gen_wav "sharps and flats"       "$WORK/m2.wav" "$MBEEP" -o "$WORK/m2.wav" -b 120 -m "C#4 Db4"
gen_wav "numeric midi"           "$WORK/m3.wav" "$MBEEP" -o "$WORK/m3.wav" -b 120 -m "60q 62h 64e"
gen_wav "durations + rests"      "$WORK/m4.wav" "$MBEEP" -o "$WORK/m4.wav" -b 100 -m "C4d C4w C4h C4q C4e C4s C4t r"
gen_wav "dotted + triplet"       "$WORK/m5.wav" "$MBEEP" -o "$WORK/m5.wav" -b 120 -m "C4q. E4q3"
gen_wav "default duration note"  "$WORK/m6.wav" "$MBEEP" -o "$WORK/m6.wav" -b 120 -m "C4"

# ---------------------------------------------------------------------------
# Morse code
# ---------------------------------------------------------------------------
gen_wav "letters"                "$WORK/c1.wav" "$MBEEP" -o "$WORK/c1.wav" -w 20 -c "THE QUICK BROWN FOX"
gen_wav "digits + punctuation"   "$WORK/c2.wav" "$MBEEP" -o "$WORK/c2.wav" -w 20 -c "73 DE W1AW = OK?"
gen_wav "prosigns + controls"    "$WORK/c3.wav" "$MBEEP" -o "$WORK/c3.wav" -w 20 -c "<BT> +*^#|% \`~"
gen_wav "farnsworth"             "$WORK/c4.wav" "$MBEEP" -o "$WORK/c4.wav" -w 13 -x 20 -c "CQ CQ"
gen_wav "codex standard"         "$WORK/c5.wav" "$MBEEP" -o "$WORK/c5.wav" --codex-wpm 20 -c "CODEX"
gen_wav "word-space speed"       "$WORK/c6.wav" "$MBEEP" -o "$WORK/c6.wav" -w 20 --wss 10 -c "A B C"
gen_wav "--fcc reporting"        "$WORK/c7.wav" "$MBEEP" -o "$WORK/c7.wav" -w 20 --fcc -c "PARIS"
gen_wav "--paris-wpm long opt"   "$WORK/c8.wav" "$MBEEP" -o "$WORK/c8.wav" --paris-wpm 25 -c "DIT"
gen_wav "accented E (UTF-8)"     "$WORK/c9.wav" "$MBEEP" -o "$WORK/c9.wav" -w 20 -c "CAF\xc3\x89"

# ---------------------------------------------------------------------------
# File and stdin input
# ---------------------------------------------------------------------------
printf 'C4q D4q\nE4q F4q\n' > "$WORK/midi.txt"
printf 'CQ DE\nTEST\n'      > "$WORK/morse.txt"
gen_wav "-i midi file"           "$WORK/i1.wav" "$MBEEP" -o "$WORK/i1.wav" -b 120 -i "$WORK/midi.txt" -m
gen_wav "-i morse file + echo"   "$WORK/i2.wav" "$MBEEP" -o "$WORK/i2.wav" -w 20 -e -i "$WORK/morse.txt" -c

# -I reads from stdin
rm -f "$WORK/i3.wav"
if printf 'C4q E4q\n' | "$MBEEP" -o "$WORK/i3.wav" -b 120 -I -m >/dev/null 2>&1 && is_wav "$WORK/i3.wav"; then
    ok "-I stdin midi"
else
    ko "-I stdin midi"
fi

# ---------------------------------------------------------------------------
# Error handling (all non-zero exit, no crash)
# ---------------------------------------------------------------------------
run_fail "bad freq (non-numeric)"  "$MBEEP" -o "$WORK/e.wav" -f abc
run_fail "bad freq (too low)"      "$MBEEP" -o "$WORK/e.wav" -f 10
run_fail "bad freq (too high)"     "$MBEEP" -o "$WORK/e.wav" -f 30000
run_fail "reject freq nan"         "$MBEEP" -o "$WORK/e.wav" -f nan
run_fail "reject freq inf"         "$MBEEP" -o "$WORK/e.wav" -f inf
run_fail "bad time (negative)"     "$MBEEP" -o "$WORK/e.wav" -t -5
run_fail "bad gap (negative)"      "$MBEEP" -o "$WORK/e.wav" -g -1
run_fail "bad repeats (negative)"  "$MBEEP" -o "$WORK/e.wav" -r -2
run_fail "bad repeats (junk)"      "$MBEEP" -o "$WORK/e.wav" -r xyz
run_fail "bad bpm (too low)"       "$MBEEP" -o "$WORK/e.wav" -b 5 -m "C4q"
run_fail "bad bpm (junk)"          "$MBEEP" -o "$WORK/e.wav" -b abc -m "C4q"
run_fail "dangling -b"             "$MBEEP" -f 440 -b
run_fail "bad wpm (too high)"      "$MBEEP" -o "$WORK/e.wav" -w 100 -c "X"
run_fail "bad wpm (junk)"          "$MBEEP" -o "$WORK/e.wav" -w abc -c "X"
run_fail "farnsworth ratio > 1"    "$MBEEP" -o "$WORK/e.wav" -w 20 -x 10 -c "X"
run_fail "invalid midi note"       "$MBEEP" -o "$WORK/e.wav" -m "Z9q"
run_fail "midi out of range"       "$MBEEP" -o "$WORK/e.wav" -m "200q"
run_fail "bad midi duration"       "$MBEEP" -o "$WORK/e.wav" -m "C4z"
run_fail "unknown option"          "$MBEEP" --nonsense-option
run_fail "input file not found"    "$MBEEP" -o "$WORK/e.wav" -i "$WORK/nope.txt" -m
run_fail "output file unwritable"  "$MBEEP" -o "$WORK/nodir/x.wav" -f 440
run_fail "double input file"       "$MBEEP" -i "$WORK/midi.txt" -i "$WORK/morse.txt" -m
# --play requires the audio device, so it is rejected in file mode (-o present).
run_fail "--play rejected with -o"  "$MBEEP" -o "$WORK/e.wav" --play "$WORK/t2.wav"

# ---------------------------------------------------------------------------
# Playback (opens the audio device) -- only when explicitly enabled
# ---------------------------------------------------------------------------
if [ "${MBEEP_PLAYBACK:-0}" = "1" ]; then
    run_ok "play tone to device"      "$MBEEP" -f 440 -t 10
    run_ok "play with -p"             "$MBEEP" -f 440 -t 10 -p -f 550 -t 10 -p
    run_ok "play midi to device"      "$MBEEP" -b 200 -m "C5e D5e E5e"
    run_ok "play morse to device"     "$MBEEP" -w 30 -c "OK"
    run_ok "default device via -d"    "$MBEEP" -d "" -f 440 -t 10

    # round-trip: generate a wav in file mode, then play it back
    "$MBEEP" -o "$WORK/rt.wav" -f 440 -t 10 >/dev/null 2>&1
    run_ok "--play round-trip"        "$MBEEP" --play "$WORK/rt.wav"
    run_fail "--play missing file"    "$MBEEP" --play "$WORK/nope.wav"
else
    printf 'note: playback tests skipped (set MBEEP_PLAYBACK=1 to run)\n'
fi

# ---------------------------------------------------------------------------
printf '\n%d passed, %d failed\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ]
