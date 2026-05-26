# Signing Provisioning

This directory contains infrastructure skeletons for production signing backends.

The goal is to show how BlockOps would provision signing boundaries without giving CI raw production private keys.

## Backends

- `github-provision-role/` bootstraps the AWS role that the protected GitHub workflow assumes to provision signing infrastructure.
- `aws-kms/` provisions an AWS KMS secp256k1 signing key plus an IAM role intended for GitHub Actions OIDC.
- `vault-transit/` provisions Vault Transit policy/JWT access and a Transit key placeholder.

## Security Model

- CI authenticates with short-lived identity.
- CI receives permission to request signing, not export private keys.
- Signing policy lives outside the GitHub Actions workflow.
- Release artifacts record key ID, signer address, and request hashes.
- Rotation is represented by key aliases/versions and signer allowlists.

## Important Vault Note

Ethereum uses secp256k1 ECDSA signatures. Stock Vault Transit deployments commonly expose NIST P-256 ECDSA rather than Ethereum secp256k1. The Vault Terraform here is useful as an access-control and signing-boundary skeleton, but production Ethereum signing requires a Vault setup that can produce secp256k1-compatible signatures or a separate signing plugin/service.

AWS KMS supports `ECC_SECG_P256K1` keys for signing, so the AWS skeleton is the more direct Ethereum-oriented path.

## Usage

These modules are intentionally not part of PR CI. Provisioning should happen from an operator workstation or a protected GitHub Actions environment with appropriate credentials.

```bash
make github-provision-plan
make github-provision-apply
```

The GitHub provisioning role is the bootstrap step. After it exists, add its `aws_provision_role_arn` output to the protected GitHub Environment `signing-production` as `AWS_PROVISION_ROLE_ARN`.

```bash
make signing-provisioning-plan TF_SIGNING_DIR=infra/signing/aws-kms
```

```bash
make signing-provisioning-plan TF_SIGNING_DIR=infra/signing/vault-transit
```

Do not commit Terraform state, plans, tokens, or real account IDs.

## GitHub Actions KMS Provisioning

The repository includes a manual workflow: `.github/workflows/provision-signing.yml`.

It checks whether `alias/blockops-release-signer` exists. If the alias is missing and the workflow input `apply=true`, it runs Terraform to provision:

- AWS KMS `ECC_SECG_P256K1` signing key
- KMS alias
- GitHub Actions OIDC IAM role for release signing
- IAM policy allowing `kms:Sign`, `kms:GetPublicKey`, and `kms:DescribeKey`

Required GitHub Environment:

- `signing-production`

Required environment variable or secret:

- `AWS_PROVISION_ROLE_ARN` - an already-bootstrapped AWS role that GitHub Actions can assume with OIDC.

Create that bootstrap role with `make github-provision-apply`, then copy the `aws_provision_role_arn` output into the protected GitHub Environment named `signing-production`.

That bootstrap role has permission to create/read the KMS and IAM resources in `infra/signing/aws-kms`.

Suggested workflow usage:

1. Run `Provision Signing` with `apply=false` to confirm the KMS alias check and Terraform plan.
2. Review the protected environment approval.
3. Re-run with `apply=true` to create the key if it is missing.
4. Save the workflow outputs as deployment environment variables for later signing workflows.

This workflow is intentionally manual and environment-gated. PR CI should never be able to create or mutate production signing keys.
