# BlockOps: Proof of Deploy

BlockOps is a Web3 DevOps proof-of-concept for recording deployment proofs on-chain.

This first slice scaffolds a Foundry-style Solidity project and adds the baseline `DeploymentRegistry` contract. The registry is intentionally small: it records deployment metadata, prevents duplicate deployment IDs, supports status changes, and keeps an on-chain event trail for release operations.

## Why?
Some JD asked for blockchain experience. So here I am boilerplating to show off what I can do.

# Prerequisites
- Rust
    - Foundry
- Terraform

## Current Scope

- Foundry project layout
- Baseline Solidity deployment registry
- Unit tests for registration, authorization, duplicate IDs, and status transitions
- Minimal deploy script
- Makefile for local workflows

## Project Layout

- `src/DeploymentRegistry.sol` - on-chain release/deployment proof registry
- `test/DeploymentRegistry.t.sol` - baseline contract tests
- `script/Deploy.s.sol` - deployment script skeleton
- `foundry.toml` - Foundry configuration
- `Makefile` - local build, test, deploy, and Anvil helpers

## Local Commands

To detect and install the local toolchain in WSL:

```bash
make install-toolchain
```

After the toolchain is installed:

```bash
make setup
make fmt-check
make build
make test
make signer-check
make manifest
make signer-smoke
```

To start a local chain:

```bash
make anvil
```

To deploy to that local chain:

```bash
make deploy-local
```

The local deploy target uses Anvil account `0` as the broadcaster and registry owner by default.

Copy the deployed registry address from the `make deploy-local` output, then register and read a sample deployment proof:

```bash
make register-sample-local REGISTRY=0xRegistryAddress
make read-sample-local REGISTRY=0xRegistryAddress
```

To generate release artifacts without broadcasting:

```bash
make manifest
make simulate-local
```

`make simulate-local` expects Anvil to be running at `http://127.0.0.1:8545`. The generated manifest, simulation report, and simulation log are written under `deployments/` and `simulations/`; those directories are ignored because they are reproducible run artifacts.

For a pinned fork simulation, provide a real RPC URL and optional block number:

```bash
make simulate CHAIN=base CHAIN_ID=8453 RPC_URL=https://your-rpc.example FORK_BLOCK=12345678
```

To run the local development signer:

```bash
make signer-local
```

Then request a release signature from a second terminal:

```bash
make sign-release-local REGISTRY=0xRegistryAddress
```

The local signer validates a release-signing request and returns an EIP-712 signature over the deployment ID, manifest hash, simulation report hash, and nonce. It uses the Anvil account `0` private key by default and is for development only.

Production signing backends are represented as fail-closed interfaces for Vault Transit and AWS KMS:

```bash
make signer-prod-config-check SIGNER_BACKEND=vault-transit
make signer-prod-config-check SIGNER_BACKEND=aws-kms
make github-provision-plan
make signing-provisioning-check TF_SIGNING_DIR=infra/signing/aws-kms
```

See `signer/README.md` for the required environment variables and production completion notes. See `infra/signing/README.md` for Terraform skeletons that provision the signing boundary.

KMS provisioning is also available as a protected manual GitHub Action:

```text
Actions -> Provision Signing -> Run workflow
```

Set `apply=false` for a check/plan run and `apply=true` to create the AWS KMS signer when the configured alias is missing.

Before running that workflow, bootstrap the AWS role GitHub will assume:

```bash
make github-provision-plan
make github-provision-apply
```

Add the `aws_provision_role_arn` Terraform output to the GitHub `signing-production` environment as `AWS_PROVISION_ROLE_ARN`.

## Sources
- [Complete Guide: Installing Foundry on Windows with WSL](https://palmartin.medium.com/complete-guide-installing-foundry-on-windows-with-wsl-9dcfe35f2bc9)
