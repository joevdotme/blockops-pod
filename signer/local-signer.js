#!/usr/bin/env node
"use strict";

const http = require("node:http");
const { execFileSync } = require("node:child_process");

const port = Number(process.env.SIGNER_PORT || 8787);
const privateKey = process.env.SIGNER_PRIVATE_KEY;
const keyId = process.env.SIGNER_KEY_ID || "local-dev-key-v1";

if (!privateKey) {
  console.error("SIGNER_PRIVATE_KEY is required for the local development signer.");
  process.exit(1);
}

function cast(args) {
  return execFileSync("cast", args, {
    encoding: "utf8",
    env: process.env,
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

const signerAddress = cast(["wallet", "address", "--private-key", privateKey]);

function isHexBytes(value, bytes) {
  return typeof value === "string" && new RegExp(`^0x[0-9a-fA-F]{${bytes * 2}}$`).test(value);
}

function isAddress(value) {
  return typeof value === "string" && /^0x[0-9a-fA-F]{40}$/.test(value);
}

function readJson(req) {
  return new Promise((resolve, reject) => {
    let body = "";

    req.on("data", (chunk) => {
      body += chunk;

      if (body.length > 32_768) {
        req.destroy();
        reject(new Error("request body too large"));
      }
    });
    req.on("end", () => {
      try {
        resolve(JSON.parse(body || "{}"));
      } catch (error) {
        reject(error);
      }
    });
    req.on("error", reject);
  });
}

function json(res, statusCode, payload) {
  const body = `${JSON.stringify(payload, null, 2)}\n`;

  res.writeHead(statusCode, {
    "content-type": "application/json",
    "cache-control": "no-store",
  });
  res.end(body);
}

function validate(payload) {
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

function typedData(payload) {
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

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/health") {
    json(res, 200, {
      status: "ok",
      signerAddress,
      keyId,
    });
    return;
  }

  if (req.method !== "POST" || req.url !== "/sign-release") {
    json(res, 404, { error: "not found" });
    return;
  }

  try {
    const payload = await readJson(req);
    const errors = validate(payload);

    if (errors.length > 0) {
      json(res, 400, { error: "invalid signing request", errors });
      return;
    }

    const data = typedData(payload);
    const signature = cast(["wallet", "sign", "--data", JSON.stringify(data), "--private-key", privateKey]);

    json(res, 200, {
      schema: "blockops.release-signature.v1",
      signedAt: new Date().toISOString(),
      keyId,
      signerAddress,
      signature,
      typedData: data,
    });
  } catch (error) {
    json(res, 500, {
      error: "signing failed",
      message: error.message,
    });
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`BlockOps local signer listening on http://127.0.0.1:${port}`);
  console.log(`Signer address: ${signerAddress}`);
  console.log(`Key ID: ${keyId}`);
});
