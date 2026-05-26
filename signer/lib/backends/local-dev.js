"use strict";

const { cast } = require("../cast");

function createLocalDevBackend(env) {
  const privateKey = env.SIGNER_PRIVATE_KEY;
  const keyId = env.SIGNER_KEY_ID || "local-dev-key-v1";

  if (!privateKey) {
    throw new Error("SIGNER_PRIVATE_KEY is required for the local development signer.");
  }

  const signerAddress = cast(["wallet", "address", "--private-key", privateKey]);

  return {
    name: "local-dev",
    keyId,
    signerAddress,

    async signTypedData(typedData) {
      return {
        signature: cast(["wallet", "sign", "--data", JSON.stringify(typedData), "--private-key", privateKey]),
        backend: {
          name: "local-dev",
          warning: "development-only signer; do not use with production keys",
        },
      };
    },
  };
}

module.exports = {
  createLocalDevBackend,
};
