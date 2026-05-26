"use strict";

const { createAwsKmsBackend } = require("./aws-kms");
const { createLocalDevBackend } = require("./local-dev");
const { createVaultTransitBackend } = require("./vault-transit");

function createBackend(env) {
  const backend = env.SIGNER_BACKEND || "local-dev";

  if (backend === "local-dev") {
    return createLocalDevBackend(env);
  }
  if (backend === "vault-transit") {
    return createVaultTransitBackend(env);
  }
  if (backend === "aws-kms") {
    return createAwsKmsBackend(env);
  }

  throw new Error(`Unsupported SIGNER_BACKEND: ${backend}`);
}

module.exports = {
  createBackend,
};
