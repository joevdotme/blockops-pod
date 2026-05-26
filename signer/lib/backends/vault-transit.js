"use strict";

const crypto = require("node:crypto");

function required(env, name) {
  if (!env[name]) {
    throw new Error(`${name} is required for SIGNER_BACKEND=vault-transit`);
  }

  return env[name];
}

function createVaultTransitBackend(env) {
  const address = required(env, "VAULT_ADDR").replace(/\/+$/, "");
  const token = required(env, "VAULT_TOKEN");
  const mount = env.VAULT_TRANSIT_MOUNT || "transit";
  const keyName = required(env, "VAULT_TRANSIT_KEY");
  const keyId = env.SIGNER_KEY_ID || `vault:${mount}/${keyName}`;
  const signerAddress = env.SIGNER_ADDRESS || null;

  return {
    name: "vault-transit",
    keyId,
    signerAddress,

    async signTypedData(typedData) {
      const canonicalTypedData = JSON.stringify(typedData);
      const digest = crypto.createHash("sha256").update(canonicalTypedData).digest("base64");
      const endpoint = `${address}/v1/${mount}/sign/${keyName}`;

      return {
        signature: null,
        backend: {
          name: "vault-transit",
          status: "not-broadcastable-skeleton",
          endpoint,
          keyId,
          signerAddress,
          request: {
            input: digest,
            hash_algorithm: "sha2-256",
          },
          note:
            "Wire this adapter to Vault Transit, require a secp256k1-compatible key path, then normalize the returned signature to Ethereum r/s/v before production use.",
        },
        audit: {
          requestSha256: crypto.createHash("sha256").update(canonicalTypedData).digest("hex"),
          tokenPresent: Boolean(token),
        },
      };
    },
  };
}

module.exports = {
  createVaultTransitBackend,
};
