"use strict";

function isHexBytes(value, bytes) {
  return typeof value === "string" && new RegExp(`^0x[0-9a-fA-F]{${bytes * 2}}$`).test(value);
}

function isAddress(value) {
  return typeof value === "string" && /^0x[0-9a-fA-F]{40}$/.test(value);
}

function validateReleaseRequest(payload) {
  const errors = [];

  if (!isHexBytes(payload.deploymentId, 32)) {
    errors.push("deploymentId must be bytes32 hex");
  }
  if (!Number.isSafeInteger(Number(payload.chainId)) || Number(payload.chainId) <= 0) {
    errors.push("chainId must be a positive integer");
  }
  if (!isAddress(payload.registryAddress)) {
    errors.push("registryAddress must be an EVM address");
  }
  if (!isHexBytes(payload.manifestHash, 32)) {
    errors.push("manifestHash must be bytes32 hex");
  }
  if (!isHexBytes(payload.simulationReportHash, 32)) {
    errors.push("simulationReportHash must be bytes32 hex");
  }
  if (!isHexBytes(payload.nonce, 32)) {
    errors.push("nonce must be bytes32 hex");
  }

  return errors;
}

function releaseTypedData(payload) {
  return {
    types: {
      EIP712Domain: [
        { name: "name", type: "string" },
        { name: "version", type: "string" },
        { name: "chainId", type: "uint256" },
        { name: "verifyingContract", type: "address" },
      ],
      ReleaseAttestation: [
        { name: "deploymentId", type: "bytes32" },
        { name: "manifestHash", type: "bytes32" },
        { name: "simulationReportHash", type: "bytes32" },
        { name: "nonce", type: "bytes32" },
      ],
    },
    primaryType: "ReleaseAttestation",
    domain: {
      name: "BlockOps Proof of Deploy",
      version: "1",
      chainId: Number(payload.chainId),
      verifyingContract: payload.registryAddress,
    },
    message: {
      deploymentId: payload.deploymentId,
      manifestHash: payload.manifestHash,
      simulationReportHash: payload.simulationReportHash,
      nonce: payload.nonce,
    },
  };
}

module.exports = {
  releaseTypedData,
  validateReleaseRequest,
};
