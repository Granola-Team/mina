#! /usr/bin/env bash

set -x
set -euo pipefail

# update and pin packages, used by CI

PACKAGES="ocaml-sodium capnp-ocaml rpc_parallel async_kernel coda_base58"

git submodule sync
git submodule update --init --recursive

for pkg in $PACKAGES; do
    echo "Pinning package: $pkg..."
    opam pin --switch=default -y add src/external/$pkg
done
