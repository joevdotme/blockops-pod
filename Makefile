SHELL := /usr/bin/env bash
export PATH := $(HOME)/.cargo/bin:$(HOME)/.foundry/bin:$(PATH)

RPC_URL ?= http://127.0.0.1:8545
ANVIL_ACCOUNT_0 ?= 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
ANVIL_PRIVATE_KEY_0 ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
OWNER ?= $(ANVIL_ACCOUNT_0)
PRIVATE_KEY ?= $(ANVIL_PRIVATE_KEY_0)
REGISTRY ?=
SAMPLE_DEPLOYMENT_ID ?= 0x256e3700d6f85b512d2c84d37bbb728099732d920ee341bf8f93ddbbe6c3c191

.PHONY: help setup install-toolchain install-apt-deps check-toolchain fmt fmt-check build test test-verbose clean anvil deploy-local register-sample-local read-sample-local inspect-tree

help:
	@echo "BlockOps local workflows"
	@echo ""
	@echo "Targets:"
	@echo "  make setup          Check required local tools"
	@echo "  make install-toolchain"
	@echo "                      Install missing Rust and Foundry tools in WSL"
	@echo "  make fmt            Format Solidity sources"
	@echo "  make fmt-check      Check Solidity formatting"
	@echo "  make build          Compile contracts"
	@echo "  make test           Run unit tests"
	@echo "  make test-verbose   Run unit tests with verbose traces"
	@echo "  make anvil          Start a local Anvil chain"
	@echo "  make deploy-local   Deploy registry to local Anvil"
	@echo "  make register-sample-local REGISTRY=0x..."
	@echo "                      Register a sample deployment proof"
	@echo "  make read-sample-local REGISTRY=0x..."
	@echo "                      Read the sample deployment proof"
	@echo "  make clean          Remove Foundry build output"

setup: check-toolchain
	@echo "Toolchain looks ready."

install-toolchain:
	@set -euo pipefail; \
	export PATH="$$HOME/.cargo/bin:$$HOME/.foundry/bin:$$PATH"; \
	if ! command -v curl >/dev/null || ! command -v git >/dev/null || ! command -v cc >/dev/null; then \
		echo "Missing curl, git, or build tools."; \
		echo "Run: make install-apt-deps"; \
		exit 1; \
	fi; \
	if ! command -v rustc >/dev/null || ! command -v cargo >/dev/null; then \
		echo "Installing Rust with rustup..."; \
		curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y; \
	else \
		echo "Rust already installed: $$(rustc --version)"; \
	fi; \
	if [ -f "$$HOME/.cargo/env" ]; then \
		. "$$HOME/.cargo/env"; \
	fi; \
	if ! command -v foundryup >/dev/null; then \
		echo "Installing Foundry installer..."; \
		curl -L https://foundry.paradigm.xyz | bash; \
	else \
		echo "Foundry installer already installed: $$(command -v foundryup)"; \
	fi; \
	export PATH="$$HOME/.foundry/bin:$$HOME/.cargo/bin:$$PATH"; \
	foundryup; \
	for tool in forge cast anvil chisel; do \
		command -v "$$tool" >/dev/null || { echo "Missing $$tool after install"; exit 1; }; \
		"$$tool" --version; \
	done

check-toolchain:
	@export PATH="$$HOME/.cargo/bin:$$HOME/.foundry/bin:$$PATH"; \
	command -v forge >/dev/null || { echo "Missing forge. Run: make install-toolchain"; exit 1; }; \
	command -v anvil >/dev/null || { echo "Missing anvil. Run: make install-toolchain"; exit 1; }; \
	command -v cast >/dev/null || { echo "Missing cast. Run: make install-toolchain"; exit 1; }

fmt: check-toolchain
	forge fmt

fmt-check: check-toolchain
	forge fmt --check

build: check-toolchain
	forge build

test: check-toolchain
	forge test

test-verbose: check-toolchain
	forge test -vvv

anvil: check-toolchain
	anvil

deploy-local: check-toolchain
	BLOCKOPS_OWNER=$(OWNER) forge script script/Deploy.s.sol:Deploy --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

register-sample-local: check-toolchain
	@test -n "$(REGISTRY)" || { echo "Usage: make register-sample-local REGISTRY=0x..."; exit 1; }
	REGISTRY_ADDRESS=$(REGISTRY) forge script script/RegisterSample.s.sol:RegisterSample --rpc-url $(RPC_URL) --private-key $(PRIVATE_KEY) --broadcast

read-sample-local: check-toolchain
	@test -n "$(REGISTRY)" || { echo "Usage: make read-sample-local REGISTRY=0x..."; exit 1; }
	cast call $(REGISTRY) "deploymentExists(bytes32)(bool)" $(SAMPLE_DEPLOYMENT_ID) --rpc-url $(RPC_URL)
	cast call $(REGISTRY) "getDeployment(bytes32)((bytes32,bytes32,bytes32,bytes32,uint256,address,string,uint8,address,uint64,uint64))" $(SAMPLE_DEPLOYMENT_ID) --rpc-url $(RPC_URL)

clean:
	rm -rf out cache broadcast

inspect-tree:
	@find . -maxdepth 3 -type f ! -path "./.git/*" ! -path "./out/*" ! -path "./cache/*" | sort
