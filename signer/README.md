# Signing Service

This directory contains the signing-service skeleton for BlockOps.

The service listens on `127.0.0.1`, validates a release-signing request, builds EIP-712 typed data, and delegates signing to a backend adapter.

The local signer is useful for proving the API boundary and release workflow. It is not production key management.

## Backends

- `local-dev` - fully working development backend using `cast wallet sign` and `SIGNER_PRIVATE_KEY`.
- `vault-transit` - production interface skeleton for HashiCorp Vault Transit.
- `aws-kms` - production interface skeleton for AWS KMS.

The production adapters are fail-closed skeletons. They validate configuration and build the backend request/audit shape, but they intentionally return `signature: null` until wired to real provider SDK/API calls and Ethereum signature normalization.

Production completion work:

- Use a secp256k1-capable key path.
- Keep CI authenticated with OIDC or short-lived identity, not raw private keys.
- Sign only policy-approved release requests.
- Convert provider signatures into Ethereum-compatible `r/s/v`.
- Record key ID, key version, signer address, request hash, and provider audit ID.
- Verify the recovered signer before accepting a signature artifact.

## Endpoints

- `GET /health`
- `POST /sign-release`

`POST /sign-release` expects:

```json
{
  "deploymentId": "0x...",
  "chainId": 31337,
  "registryAddress": "0x...",
  "manifestHash": "0x...",
  "simulationReportHash": "0x...",
  "nonce": "0x..."
}
```

The response includes the signer address, key ID, EIP-712 typed data, and signature.

## Local Development

```bash
make signer-local
make signer-service SIGNER_BACKEND=local-dev
make sign-release-local REGISTRY=0xRegistryAddress
make signer-smoke
```

## Production Interface Checks

Vault Transit:

```bash
SIGNER_BACKEND=vault-transit \
VAULT_ADDR=https://vault.example.com \
VAULT_TOKEN=redacted \
VAULT_TRANSIT_KEY=blockops-release-signer \
SIGNER_ADDRESS=0xSignerAddress \
make signer-prod-config-check
```

Provisioning skeletons live under `infra/signing/`:

- `infra/signing/aws-kms` provisions a KMS secp256k1 signing key plus a GitHub Actions OIDC role.
- `infra/signing/vault-transit` provisions a Vault Transit signing policy/JWT role/key placeholder.

Validate formatting, if Terraform is installed:

```bash
make signing-provisioning-check TF_SIGNING_DIR=infra/signing/aws-kms
make signing-provisioning-check TF_SIGNING_DIR=infra/signing/vault-transit
```

AWS KMS:

```bash
SIGNER_BACKEND=aws-kms \
AWS_REGION=us-east-1 \
AWS_KMS_KEY_ID=alias/blockops-release-signer \
SIGNER_ADDRESS=0xSignerAddress \
make signer-prod-config-check
```
