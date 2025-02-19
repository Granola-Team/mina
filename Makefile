########################################
## Configuration

.EXPORT_ALL_VARIABLES:

OCAML_VERSION = "4.14.0"
WORD_SIZE = "64"
DUNE_PROFILE ?= dev
OPAMROOT ?= ../opam
RUSTUP_HOME ?= ../rustup
CARGO_HOME ?= ../cargo
TMPDIR ?= /tmp
GENESIS_DIR := $(TMPDIR)/coda_cache_dir
GITHASH := $(shell git rev-parse --short=8 HEAD)
GITLONGHASH := $(shell git rev-parse HEAD)
MINA_COMMIT_SHA1 := $(GITLONGHASH)

# Unique signature of libp2p code tree
LIBP2P_HELPER_SIG := $(shell cd src/app/libp2p_helper ; find . -type f -print0  | xargs -0 sha1sum | sort | sha1sum | cut -f 1 -d ' ')

git_hooks: $(wildcard scripts/git_hooks/*)
	@case "$$(file .git | cut -d: -f2)" in \
	' ASCII text') \
	    echo 'refusing to install git hooks in worktree' \
	    break;; \
	' directory') \
	    for f in $^; do \
	      [ ! -f ".git/hooks/$$(basename $$f)" ] && ln -s ../../$$f .git/hooks/; \
	    done; \
	    break;; \
	*) \
	    echo 'unhandled case when installing git hooks' \
	    exit 1 \
	    break;; \
	esac

all: clean build

clean:
	$(info Removing previous build artifacts)
	@rm -rf _build
	@rm -rf _coverage
	@rm -f src/config.mlh
	@rm -rf src/libp2p_ipc/build/
	@rm -rf src/app/libp2p_helper/result src/libp2p_ipc/libp2p_ipc.capnp.go

# enforces the OCaml version being used
ocaml_version:
	@if ! ocamlopt -config | grep "version:" | grep $(OCAML_VERSION); then echo "incorrect OCaml version, expected version $(OCAML_VERSION)" ; exit 1; fi

# enforce machine word size
ocaml_word_size:
	@if ! ocamlopt -config | grep "word_size:" | grep $(WORD_SIZE); then echo "invalid machine word size, expected $(WORD_SIZE)" ; exit 1; fi

$(OPAMROOT)/config: opam.export
	@echo OPAMROOT=$$OPAMROOT
	opam init -n -y --reinit --bare
	opam switch --switch=default -y import opam.export
	scripts/pin-external-packages.sh

opam_init: $(OPAMROOT)/config

ocaml_checks: opam_init ocaml_version ocaml_word_size

rust_init: $(CARGO_HOME)/bin/cargo

$(CARGO_HOME)/bin/cargo:
	curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y

libp2p_helper:
	make -C src/app/libp2p_helper

genesis_ledger: ocaml_checks
	$(info Building runtime_genesis_ledger)
	ulimit -s 65532 && (ulimit -n 10240 || true) && env MINA_COMMIT_SHA1=$(GITLONGHASH) dune exec --profile=$(DUNE_PROFILE) src/app/runtime_genesis_ledger/runtime_genesis_ledger.exe -- --genesis-dir $(GENESIS_DIR)
	$(info Genesis ledger and genesis proof generated)

build: ocaml_checks reformat-diff libp2p_helper rust_init
	dune build src/app/logproc/logproc.exe --profile=$(DUNE_PROFILE)
	dune build src/app/cli/src/mina.exe --profile=$(DUNE_PROFILE)

build_all_sigs: ocaml_checks git_hooks reformat-diff libp2p_helper
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && env MINA_COMMIT_SHA1=$(GITLONGHASH) dune build src/app/logproc/logproc.exe src/app/cli/src/mina.exe src/app/cli/src/mina_testnet_signatures.exe src/app/cli/src/mina_mainnet_signatures.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

build_archive: ocaml_checks reformat-diff
	dune build src/app/archive/archive.exe --profile=$(DUNE_PROFILE)

build_archive_all_sigs: ocaml_checks git_hooks reformat-diff
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/archive/archive.exe src/app/archive/archive_testnet_signatures.exe src/app/archive/archive_mainnet_signatures.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

build_rosetta: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/archive/archive.exe src/app/rosetta/rosetta.exe src/app/rosetta/ocaml-signer/signer.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

build_rosetta_all_sigs: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/archive/archive.exe src/app/archive/archive_testnet_signatures.exe src/app/archive/archive_mainnet_signatures.exe src/app/rosetta/rosetta.exe src/app/rosetta/rosetta_testnet_signatures.exe src/app/rosetta/rosetta_mainnet_signatures.exe src/app/rosetta/ocaml-signer/signer.exe src/app/rosetta/ocaml-signer/signer_testnet_signatures.exe src/app/rosetta/ocaml-signer/signer_mainnet_signatures.exe --profile=$(DUNE_PROFILE)
	$(info Build complete)

build_intgtest: ocaml_checks
	$(info Starting Build)
	dune build --profile=integration_tests src/app/test_executive/test_executive.exe src/app/logproc/logproc.exe
	$(info Build complete)

client_sdk: ocaml_checks
	dune build src/app/client_sdk/client_sdk.bc.js --profile=nonconsensus_mainnet

client_sdk_test_sigs: ocaml_checks
	dune build src/app/client_sdk/tests/test_signatures.exe --profile=mainnet

client_sdk_test_sigs_nonconsensus: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/client_sdk/tests/test_signatures_nonconsensus.exe --profile=nonconsensus_mainnet
	$(info Build complete)

rosetta_lib_encodings: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/lib/rosetta_lib/test/test_encodings.exe --profile=mainnet
	$(info Build complete)

rosetta_lib_encodings_nonconsensus: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/nonconsensus/rosetta_lib/test/test_encodings.exe --profile=nonconsensus_mainnet
	$(info Build complete)

dhall_types: ocaml_checks
	dune build src/app/dhall_types/dump_dhall_types.exe --profile=dev

replayer: ocaml_checks
	dune build src/app/replayer/replayer.exe --profile=testnet_postake_medium_curves

delegation_compliance: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/delegation_compliance/delegation_compliance.exe --profile=testnet_postake_medium_curves
	$(info Build complete)

missing_blocks_auditor: ocaml_checks
	dune build src/app/missing_blocks_auditor/missing_blocks_auditor.exe --profile=testnet_postake_medium_curves

extract_blocks: ocaml_checks
	dune build src/app/extract_blocks/extract_blocks.exe --profile=testnet_postake_medium_curves

archive_blocks: ocaml_checks
	dune build src/app/archive_blocks/archive_blocks.exe --profile=testnet_postake_medium_curves

patch_archive_test: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/patch_archive_test/patch_archive_test.exe --profile=testnet_postake_medium_curves
	$(info Build complete)

genesis_ledger_from_tsv: ocaml_checks
	dune build src/app/genesis_ledger_from_tsv/genesis_ledger_from_tsv.exe --profile=testnet_postake_medium_curves

swap_bad_balances: ocaml_checks
	$(info Starting Build)
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build src/app/swap_bad_balances/swap_bad_balances.exe --profile=testnet_postake_medium_curves
	$(info Build complete)

macos-portable:
	@rm -rf _build/coda-daemon-macos/
	@rm -rf _build/coda-daemon-macos.zip
	@./scripts/macos-portable.sh _build/default/src/app/cli/src/mina.exe src/app/libp2p_helper/result/bin/libp2p_helper _build/coda-daemon-macos
	@cp -a package/keys/. _build/coda-daemon-macos/keys/
	@cd _build/coda-daemon-macos && zip -r ../coda-daemon-macos.zip .
	@echo Find coda-daemon-macos.zip inside _build/

update-graphql:
	ulimit -s 65532 && (ulimit -n 10240 || true) && dune build --profile=$(DUNE_PROFILE) graphql_schema.json

########################################
## Lint

reformat: ocaml_checks
	dune exec --profile=$(DUNE_PROFILE) src/app/reformat/reformat.exe -- -path .

reformat-diff:
	@ocamlformat --doc-comments=before --inplace $(shell git status -s | cut -c 4- | grep '\.mli\?$$' | while IFS= read -r f; do stat "$$f" >/dev/null 2>&1 && echo "$$f"; done) || true

check-format: ocaml_checks
	dune exec --profile=$(DUNE_PROFILE) src/app/reformat/reformat.exe -- -path . -check

check-snarky-submodule:
	./scripts/check-snarky-submodule.sh

#######################################
## Environment setup

macos-setup-download:
	./scripts/macos-setup-brew.sh

########################################
## Artifacts

publish-macos:
	@./scripts/publish-macos.sh

deb:
	./scripts/rebuild-deb.sh
	./scripts/archive/build-release-archives.sh
	@mkdir -p /tmp/artifacts
	@cp _build/mina*.deb /tmp/artifacts/.

deb_optimized:
	./scripts/rebuild-deb.sh "optimized"
	./scripts/archive/build-release-archives.sh
	@mkdir -p /tmp/artifacts
	@cp _build/mina*.deb /tmp/artifacts/.

test_executive_deb:
	./scripts/rebuild_test_executive_deb.sh

build_pv_keys: ocaml_checks
	$(info Building keys)
	ulimit -s 65532 && (ulimit -n 10240 || true) && env MINA_COMMIT_SHA1=$(GITLONGHASH) dune exec --profile=$(DUNE_PROFILE) src/lib/snark_keys/gen_keys/gen_keys.exe -- --generate-keys-only
	$(info Keys built)

build_or_download_pv_keys: ocaml_checks
	$(info Building keys)
	ulimit -s 65532 && (ulimit -n 10240 || true) && env MINA_COMMIT_SHA1=$(GITLONGHASH) dune exec --profile=$(DUNE_PROFILE) src/lib/snark_keys/gen_keys/gen_keys.exe -- --generate-keys-only
	$(info Keys built)

publish_deb:
	@./scripts/publish-deb.sh

publish_debs:
	@./buildkite/scripts/publish-deb.sh

genesiskeys:
	@mkdir -p /tmp/artifacts
	@cp _build/default/src/lib/mina_base/sample_keypairs.ml /tmp/artifacts/.
	@cp _build/default/src/lib/mina_base/sample_keypairs.json /tmp/artifacts/.

##############################################
## Genesis ledger in OCaml from running daemon

genesis-ledger-ocaml:
	@./scripts/generate-genesis-ledger.py .genesis-ledger.ml.jinja

########################################
## Tests

test-ppx:
	$(MAKE) -C src/lib/ppx_coda/tests

web:
	./scripts/web.sh

########################################
## Benchmarks

benchmarks: ocaml_checks
	dune build src/app/benchmarks/main.exe

########################################
# Coverage testing and output

test-coverage: SHELL := /bin/bash
test-coverage: libp2p_helper
	scripts/create_coverage_profiles.sh

# we don't depend on test-coverage, which forces a run of all unit tests
coverage-html:
	bisect-ppx-report html --source-path=_build/default --coverage-path=_build/default

coverage-summary:
	bisect-ppx-report summary --coverage-path=_build/default --per-file

########################################
# Diagrams for documentation

%.dot.png: %.dot
	dot -Tpng $< > $@

%.tex.pdf: %.tex
	cd $(dir $@) && pdflatex -halt-on-error $(notdir $<)
	cp $(@:.tex.pdf=.pdf) $@

%.tex.png: %.tex.pdf
	convert -density 600x600 $< -quality 90 -resize 1080x1080 $@

%.conv.tex.png: %.conv.tex
	cd $(dir $@) && pdflatex -halt-on-error -shell-escape $(notdir $<)

doc_diagram_sources=$(addprefix docs/res/,*.dot *.tex *.conv.tex)
doc_diagram_sources+=$(addprefix rfcs/res/,*.dot *.tex *.conv.tex)
doc_diagrams: $(addsuffix .png,$(wildcard $(doc_diagram_sources)))

########################################
# Generate odoc documentation

ml-docs: ocaml_checks
	dune build --profile=$(DUNE_PROFILE) @doc

########################################
# To avoid unintended conflicts with file names, always add new targets to .PHONY
# unless there is a reason not to.
# https://www.gnu.org/software/make/manual/html_node/Phony-Targets.html
# HACK: cat Makefile | egrep '^\w.*' | sed 's/:/ /' | awk '{print $1}' | grep -v myprocs | sort | xargs

.PHONY: all build check-format clean client_sdk client_sdk_test_sigs deb reformat doc_diagrams ml-docs macos-setup-download libp2p_helper dhall_types replayer missing_blocks_auditor extract_blocks archive_blocks genesis_ledger_from_tsv ocaml_version ocaml_word_size ocaml_checks
