#!/bin/sh

set -eu

if [ -z "${MARLIN_PLONK_STUBS-}" ]; then
    rustup show
    cargo --version
    cargo build --release
    MARLIN_PLONK_STUBS="target/release"
fi

cp "$MARLIN_PLONK_STUBS/libmarlin_plonk_stubs.a" .
