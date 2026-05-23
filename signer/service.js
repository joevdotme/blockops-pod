#!/usr/bin/env node
"use strict";

const http = require("node:http");
const { createBackend } = require("./lib/backends");
const { json, readJson } = require("./lib/http");
const { releaseTypedData, validateReleaseRequest } = require("./lib/protocol");

const port = Number(process.env.SIGNER_PORT || 8787);
const backend = createBackend(process.env);

const server = http.createServer(async (req, res) => {
  if (req.method === "GET" && req.url === "/health") {
    json(res, 200, {
      status: "ok",
      backend: backend.name,
      signerAddress: backend.signerAddress,
      keyId: backend.keyId,
    });
    return;
  }

  if (req.method !== "POST" || req.url !== "/sign-release") {
    json(res, 404, { error: "not found" });
    return;
  }

  try {
    const payload = await readJson(req);
    const errors = validateReleaseRequest(payload);

    if (errors.length > 0) {
      json(res, 400, { error: "invalid signing request", errors });
      return;
    }

    const typedData = releaseTypedData(payload);
    const signed = await backend.signTypedData(typedData);

    json(res, signed.signature ? 200 : 202, {
      schema: "blockops.release-signature.v1",
      signedAt: new Date().toISOString(),
      backend: backend.name,
      keyId: backend.keyId,
      signerAddress: backend.signerAddress,
      signature: signed.signature,
      typedData,
      backendResult: signed.backend,
      audit: signed.audit,
    });
  } catch (error) {
    json(res, 500, {
      error: "signing failed",
      message: error.message,
    });
  }
});

server.listen(port, "127.0.0.1", () => {
  console.log(`BlockOps signer listening on http://127.0.0.1:${port}`);
  console.log(`Backend: ${backend.name}`);
  console.log(`Signer address: ${backend.signerAddress || "not configured"}`);
  console.log(`Key ID: ${backend.keyId}`);
});
