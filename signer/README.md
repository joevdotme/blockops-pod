# Local Signing Service

This directory contains the development signing-service skeleton for BlockOps.

The service is intentionally local-only. It listens on `127.0.0.1`, validates a release-signing request, builds EIP-712 typed data, and signs it with `cast wallet sign`.

The local signer is useful for proving the API boundary and release workflow. It is not production key management. A production implementation should replace the private-key backend with Vault Transit, cloud KMS, Safe, or another controlled signing boundary.

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
