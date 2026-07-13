#!/usr/bin/env bash
#
# mayhem/build.sh — build SDL_ttf's fuzz harness + a clean test build.
#
# Runs inside the commit image (mayhem/Dockerfile) as `mayhem` in /mayhem. The base image
# (ghcr.io/mayhemheroes/base) exports the build contract (CC/CXX/LIB_FUZZING_ENGINE/
# SANITIZER_FLAGS/DEBUG_FLAGS/STANDALONE_FUZZ_MAIN/SRC). SDL3, FreeType and HarfBuzz come
# from apt (libsdl3-dev/libfreetype-dev/libharfbuzz-dev), installed by the Dockerfile as
# root before this runs, so the build is fully offline-resolvable (no vendored submodules
# to fetch: SDLTTF_VENDORED=OFF, SDLTTF_PLUTOSVG=OFF).
#
# Layout produced:
#   /mayhem/fuzz_open_font_from_mem             libFuzzer target (sanitized lib + harness)
#   /mayhem/fuzz_open_font_from_mem-standalone  run-once reproducer (no libFuzzer runtime)
#   /mayhem/sdlttf_selftest                     functional test runner (NORMAL flags) for test.sh
set -euo pipefail

# clang rejects SOURCE_DATE_EPOCH='' (empty) — it must be unset or a valid integer.
[ -n "${SOURCE_DATE_EPOCH:-}" ] || unset SOURCE_DATE_EPOCH

: "${SANITIZER_FLAGS=-fsanitize=address,undefined -fno-sanitize-recover=all -fno-omit-frame-pointer}"
: "${DEBUG_FLAGS:=-g -gdwarf-3}"
: "${CC:=clang}" ; : "${CXX:=clang++}" ; : "${LIB_FUZZING_ENGINE:=-fsanitize=fuzzer}"
: "${MAYHEM_JOBS:=$(nproc)}"
: "${COVERAGE_FLAGS=}"
export SANITIZER_FLAGS DEBUG_FLAGS CC CXX LIB_FUZZING_ENGINE MAYHEM_JOBS COVERAGE_FLAGS

cd "$SRC"

SDL3_CFLAGS="$(pkg-config --cflags sdl3)"
SDL3_LIBS="$(pkg-config --libs sdl3)"
DEP_LIBS="$(pkg-config --libs freetype2 harfbuzz)"

CMAKE_COMMON=(
    -DCMAKE_C_COMPILER="$CC" -DCMAKE_CXX_COMPILER="$CXX"
    -DBUILD_SHARED_LIBS=OFF
    -DSDLTTF_VENDORED=OFF
    -DSDLTTF_HARFBUZZ=ON
    -DSDLTTF_PLUTOSVG=OFF
    -DSDLTTF_SAMPLES=OFF
    -DSDLTTF_INSTALL=OFF
)

# ---------------------------------------------------------------------------
# 1) Build the SDL3_ttf library ITSELF with $SANITIZER_FLAGS + $DEBUG_FLAGS so the FUZZED
#    code (font parsing/layout/rendering) is instrumented and carries DWARF<4 symbols.
#    -fsanitize=fuzzer-no-link adds SanitizerCoverage inside the library so libFuzzer gets
#    coverage feedback from the parser, not just the harness.
# ---------------------------------------------------------------------------
rm -rf "$SRC/build-fuzz"
cmake -S "$SRC" -B "$SRC/build-fuzz" \
    -DCMAKE_BUILD_TYPE=Debug \
    "${CMAKE_COMMON[@]}" \
    -DCMAKE_C_FLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link" \
    -DCMAKE_CXX_FLAGS="$SANITIZER_FLAGS $DEBUG_FLAGS -fsanitize=fuzzer-no-link"
cmake --build "$SRC/build-fuzz" -j"$MAYHEM_JOBS"

SDLTTF_A="$(find "$SRC/build-fuzz" -name 'libSDL3_ttf*.a' | head -n1)"
[ -n "$SDLTTF_A" ] || { echo "ERROR: sanitized libSDL3_ttf static archive not found" >&2; exit 1; }
echo "sanitized lib: $SDLTTF_A"

# ---------------------------------------------------------------------------
# 2) Compile the harness TWICE: once with the fuzzing engine (the fuzzer), once with the
#    standalone run-once driver (a non-fuzzer reproducer). Both link the sanitized lib +
#    SDL3/FreeType/HarfBuzz and respect $SANITIZER_FLAGS + $DEBUG_FLAGS.
# ---------------------------------------------------------------------------
HARNESS="$SRC/mayhem/fuzz_open_font_from_mem.c"
INCLUDES="-I$SRC/include $SDL3_CFLAGS"

$CC $SANITIZER_FLAGS $DEBUG_FLAGS $LIB_FUZZING_ENGINE \
    "$HARNESS" $INCLUDES \
    "$SDLTTF_A" $SDL3_LIBS $DEP_LIBS -lm \
    -o /mayhem/fuzz_open_font_from_mem

$CC $SANITIZER_FLAGS $DEBUG_FLAGS \
    "$STANDALONE_FUZZ_MAIN" "$HARNESS" $INCLUDES \
    "$SDLTTF_A" $SDL3_LIBS $DEP_LIBS -lm \
    -o /mayhem/fuzz_open_font_from_mem-standalone

# ---------------------------------------------------------------------------
# 3) Build the functional TEST runner with the project's NORMAL flags (clean, independent
#    of the sanitized build). Known-answer oracle over the public API against DejaVu Sans
#    (fonts-dejavu-core) — see mayhem/sdlttf_selftest.c. test.sh only RUNS it.
# ---------------------------------------------------------------------------
rm -rf "$SRC/build-test"
cmake -S "$SRC" -B "$SRC/build-test" \
    -DCMAKE_BUILD_TYPE=Release \
    "${CMAKE_COMMON[@]}" \
    -DCMAKE_C_FLAGS="$COVERAGE_FLAGS" \
    -DCMAKE_CXX_FLAGS="$COVERAGE_FLAGS"
cmake --build "$SRC/build-test" -j"$MAYHEM_JOBS"

SDLTTF_TEST_A="$(find "$SRC/build-test" -name 'libSDL3_ttf*.a' | head -n1)"
[ -n "$SDLTTF_TEST_A" ] || { echo "ERROR: test libSDL3_ttf static archive not found" >&2; exit 1; }

$CC -O2 $COVERAGE_FLAGS \
    "$SRC/mayhem/sdlttf_selftest.c" -I"$SRC/include" $SDL3_CFLAGS \
    "$SDLTTF_TEST_A" $SDL3_LIBS $DEP_LIBS -lm \
    -o /mayhem/sdlttf_selftest

echo "build.sh OK: $(ls -1 /mayhem/fuzz_open_font_from_mem /mayhem/fuzz_open_font_from_mem-standalone /mayhem/sdlttf_selftest)"
