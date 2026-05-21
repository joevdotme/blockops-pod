#!/usr/bin/env node
"use strict";

const fs = require("node:fs");
const http = require("node:http");
const { execFileSync } = require("node:child_process");

const chain = process.env.CHAIN || "local";
const chainId = Number(process.env.CHAIN_ID || 31337);
const registryAddress = process.env.REGISTRY_ADDRESS;
const signerUrl = new URL(process.env.SIGNER_URL || "http://127.0.0.1:8787");
const manifestPath = process.env.MANIFEST || `deployments/${chain}/manifest.json`;
const manifestHashPath = process.env.MANIFEST_HASH || `deployments/${chain}/manifest.hash`;
const simulationReportHashPath =
  process.env.SIMULATION_REPORT_HASH || `simulations/${chain}/simulation-report.hash`;
const signatureReport = process.env.SIGNATURE_REPORT || `signatures/${chain}/release-signature.json`;

if (!registryAddress) {
  console.error("REGISTRY_ADDRESS is required.");
  process.exit(1);
}

function readTrimmed(path) {
  return fs.readFileSync(path, "utf8").trim();
}

function cast(args) {
  return execFileSync("cast", args, {
    encoding: "utf8",
    env: process.env,
    stdio: ["ignore", "pipe", "pipe"],
  }).trim();
}

function postJson(path, payload) {
  const body = JSON.stringify(payload);

  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        hostname: signerUrl.hostname,
        port: signerUrl.port || 80,
        path,
        method: "POST",
        headers: {
          "content-type": "application/json",
          "content-length": Buffer.byteLength(body),
        },
      },
      (res) => {
        let response = "";

        res.on("data", (chunk) => {
          response += chunk;
        });
        res.on("end", () => {
          if (res.statusCode < 200 || res.statusCode >= 300) {
            reject(new Error(`signer returned ${res.statusCode}: ${response}`));
            return;
          }

          resolve(JSON.parse(response));
        });
      },
    );

    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

async function main() {
  const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
  const manifestHash = readTrimmed(manifestHashPath);
  const simulationReportHash = readTrimmed(simulationReportHashPath);
  const deploymentId = manifest.release.sampleDeploymentId;
  const nonce = cast(["keccak", `${manifest.git.commit}:${manifestHash}:${simulationReportHash}`]);

  const response = await postJson("/sign-release", {
    deploymentId,
    chainId,
    registryAddress,
    manifestHash,
    simulationReportHash,
    nonce,
  });

  fs.mkdirSync(signatureReport.slice(0, signatureReport.lastIndexOf("/")), { recursive: true });
  fs.writeFileSync(signatureReport, `${JSON.stringify(response, null, 2)}\n`);

  console.log(`Wrote ${signatureReport}`);
  console.log(`Signer: ${response.signerAddress}`);
  console.log(`Signature: ${response.signature}`);
}

main().catch((error) => {
  console.error(error.message);
  process.exit(1);
});
