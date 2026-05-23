SHELL := /usr/bin/env bash
export PATH := $(HOME)/.cargo/bin:$(HOME)/.foundry/bin:$(PATH)

RPC_URL ?= http://127.0.0.1:8545
CHAIN ?= local
CHAIN_ID ?= 31337
FORK_BLOCK ?=
ANVIL_ACCOUNT_0 ?= 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266
ANVIL_PRIVATE_KEY_0 ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
OWNER ?= $(ANVIL_ACCOUNT_0)
PRIVATE_KEY ?= $(ANVIL_PRIVATE_KEY_0)
REGISTRY ?=
SAMPLE_DEPLOYMENT_ID ?= 0x256e3700d6f85b512d2c84d37bbb728099732d920ee341bf8f93ddbbe6c3c191
MANIFEST ?= deployments/$(CHAIN)/manifest.json
SIMULATION_REPORT ?= simulations/$(CHAIN)/simulation-report.json
SIMULATION_LOG ?= simulations/$(CHAIN)/simulation.log
SIGNER_PORT ?= 8787
SIGNER_URL ?= http://127.0.0.1:$(SIGNER_PORT)
SIGNER_PRIVATE_KEY ?= $(ANVIL_PRIVATE_KEY_0)
SIGNER_KEY_ID ?= local-dev-key-v1
SIGNER_BACKEND ?= local-dev
SIGN_REGISTRY ?= $(REGISTRY)
SIGNATURE_REPORT ?= signatures/$(CHAIN)/release-signature.json
TF_SIGNING_DIR ?= infra/signing/aws-kms

.PHONY: help setup install-toolchain install-apt-deps check-toolchain fmt fmt-check build test test-verbose clean anvil manifest simulate simulate-local signer-check signer-local signer-service signer-prod-config-check signing-provisioning-check sign-release-local signer-smoke deploy-local register-sample-local read-sample-local inspect-tree

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
	@echo "  make manifest       Generate deployment manifest"
	@echo "  make simulate       Simulate deployment against RPC_URL/fork"
	@echo "  make simulate-local Simulate deployment against local Anvil"
	@echo "  make signer-check   Check signer JavaScript syntax"
	@echo "  make signer-local   Start local signing service"
	@echo "  make signer-service SIGNER_BACKEND=..."
	@echo "                      Start configured signing service"
	@echo "  make signer-prod-config-check SIGNER_BACKEND=vault-transit|aws-kms"
	@echo "                      Validate production signer configuration"
	@echo "  make signing-provisioning-check TF_SIGNING_DIR=infra/signing/aws-kms"
	@echo "                      Validate Terraform formatting when terraform is installed"
	@echo "  make sign-release-local REGISTRY=0x..."
	@echo "                      Request a local release signature"
	@echo "  make signer-smoke   Run local signer smoke test"
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

manifest: check-toolchain build
	CHAIN=$(CHAIN) CHAIN_ID=$(CHAIN_ID) FORK_BLOCK=$(FORK_BLOCK) RPC_URL=$(RPC_URL) OWNER=$(OWNER) bash scripts/generate-manifest.sh

simulate: check-toolchain manifest
	@mkdir -p "$$(dirname "$(SIMULATION_REPORT)")"
	@set -euo pipefail; \
	fork_block_args=""; \
	if [ -n "$(FORK_BLOCK)" ]; then fork_block_args="--fork-block-number $(FORK_BLOCK)"; fi; \
	BLOCKOPS_OWNER=$(OWNER) forge script script/SimulateDeployment.s.sol:SimulateDeployment --rpc-url $(RPC_URL) $$fork_block_args --private-key $(PRIVATE_KEY) > "$(SIMULATION_LOG)"; \
	manifest_hash="$$(cat "$$(dirname "$(MANIFEST)")/manifest.hash")"; \
	log_hash="$$(cast keccak "$$(cat "$(SIMULATION_LOG)")")"; \
	created_at="$$(date -u +"%Y-%m-%dT%H:%M:%SZ")"; \
	printf '{\n' > "$(SIMULATION_REPORT)"; \
	printf '  "schema": "blockops.simulation-report.v1",\n' >> "$(SIMULATION_REPORT)"; \
	printf '  "createdAt": "%s",\n' "$$created_at" >> "$(SIMULATION_REPORT)"; \
	printf '  "chain": "$(CHAIN)",\n' >> "$(SIMULATION_REPORT)"; \
	printf '  "chainId": $(CHAIN_ID),\n' >> "$(SIMULATION_REPORT)"; \
	if [ -n "$(FORK_BLOCK)" ]; then printf '  "forkBlock": $(FORK_BLOCK),\n' >> "$(SIMULATION_REPORT)"; else printf '  "forkBlock": null,\n' >> "$(SIMULATION_REPORT)"; fi; \
	printf '  "rpcUrl": "redacted",\n' >> "$(SIMULATION_REPORT)"; \
	printf '  "owner": "$(OWNER)",\n' >> "$(SIMULATION_REPORT)"; \
	printf '  "manifest": "$(MANIFEST)",\n' >> "$(SIMULATION_REPORT)"; \
	printf '  "manifestHash": "%s",\n' "$$manifest_hash" >> "$(SIMULATION_REPORT)"; \
	printf '  "simulationScript": "script/SimulateDeployment.s.sol:SimulateDeployment",\n' >> "$(SIMULATION_REPORT)"; \
	printf '  "simulationLog": "$(SIMULATION_LOG)",\n' >> "$(SIMULATION_REPORT)"; \
	printf '  "simulationLogHash": "%s",\n' "$$log_hash" >> "$(SIMULATION_REPORT)"; \
	printf '  "status": "passed"\n' >> "$(SIMULATION_REPORT)"; \
	printf '}\n' >> "$(SIMULATION_REPORT)"; \
	report_hash="$$(cast keccak "$$(cat "$(SIMULATION_REPORT)")")"; \
	printf '%s\n' "$$report_hash" > "$$(dirname "$(SIMULATION_REPORT)")/simulation-report.hash"; \
	echo "Wrote $(SIMULATION_REPORT)"; \
	echo "Simulation report hash: $$report_hash"

simulate-local: simulate

signer-check:
	@find signer -name "*.js" -print0 | xargs -0 -n1 node --check

signer-local: check-toolchain
	SIGNER_PORT=$(SIGNER_PORT) SIGNER_PRIVATE_KEY=$(SIGNER_PRIVATE_KEY) SIGNER_KEY_ID=$(SIGNER_KEY_ID) node signer/local-signer.js

signer-service:
	SIGNER_BACKEND=$(SIGNER_BACKEND) SIGNER_PORT=$(SIGNER_PORT) node signer/service.js

signer-prod-config-check:
	@test "$(SIGNER_BACKEND)" != "local-dev" || { echo "Use SIGNER_BACKEND=vault-transit or SIGNER_BACKEND=aws-kms"; exit 1; }
	SIGNER_BACKEND=$(SIGNER_BACKEND) node -e 'const { createBackend } = require("./signer/lib/backends"); const backend = createBackend(process.env); console.log(JSON.stringify({ backend: backend.name, keyId: backend.keyId, signerAddress: backend.signerAddress }, null, 2));'

signing-provisioning-check:
	@if ! command -v terraform >/dev/null; then \
		echo "terraform not installed; skipping provisioning format check"; \
	else \
		terraform -chdir=$(TF_SIGNING_DIR) fmt -check; \
	fi

sign-release-local: check-toolchain
	@test -n "$(SIGN_REGISTRY)" || { echo "Usage: make sign-release-local REGISTRY=0x..."; exit 1; }
	SIGNER_URL=$(SIGNER_URL) CHAIN=$(CHAIN) CHAIN_ID=$(CHAIN_ID) REGISTRY_ADDRESS=$(SIGN_REGISTRY) SIGNATURE_REPORT=$(SIGNATURE_REPORT) node signer/request-signature.js

signer-smoke: check-toolchain simulate-local
	SIGNER_PRIVATE_KEY=$(SIGNER_PRIVATE_KEY) SIGNER_KEY_ID=$(SIGNER_KEY_ID) SIGNER_PORT=$(SIGNER_PORT) CHAIN=$(CHAIN) CHAIN_ID=$(CHAIN_ID) SIGNATURE_REPORT=$(SIGNATURE_REPORT) bash signer/smoke-test.sh

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
	rm -rf out cache broadcast deployments simulations signatures

inspect-tree:
	@find . -maxdepth 3 -type f ! -path "./.git/*" ! -path "./out/*" ! -path "./cache/*" | sort
