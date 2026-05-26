"use strict";

const crypto = require("node:crypto");

function required(env, name) {
  if (!env[name]) {
    throw new Error(`${name} is required for SIGNER_BACKEND=aws-kms`);
  }

  return env[name];
}

function createAwsKmsBackend(env) {
  const keyId = required(env, "AWS_KMS_KEY_ID");
  const region = required(env, "AWS_REGION");
  const signerAddress = env.SIGNER_ADDRESS || null;

  return {
    name: "aws-kms",
    keyId,
    signerAddress,

    async signTypedData(typedData) {
      const canonicalTypedData = JSON.stringify(typedData);
      const digest = crypto.createHash("sha256").update(canonicalTypedData).digest("hex");

      return {
        signature: null,
        backend: {
          name: "aws-kms",
          status: "not-broadcastable-skeleton",
          keyId,
          region,
          signerAddress,
          request: {
            KeyId: keyId,
            MessageType: "DIGEST",
            SigningAlgorithm: "ECDSA_SHA_256",
            MessageSha256: digest,
          },
          note:
            "Wire this adapter to AWS KMS with an ECC_SECG_P256K1 key, DER-decode the ECDSA signature, derive recovery id, and normalize to Ethereum r/s/v before production use.",
        },
        audit: {
          requestSha256: digest,
        },
      };
    },
  };
}

module.exports = {
  createAwsKmsBackend,
};
