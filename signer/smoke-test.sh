#!/usr/bin/env bash
set -euo pipefail

port="${SIGNER_PORT:-8787}"
registry_address="${REGISTRY_ADDRESS:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
log_file="/tmp/blockops-local-signer.log"

SIGNER_PORT="${port}" node signer/local-signer.js > "${log_file}" 2>&1 &
signer_pid="$!"

cleanup() {
  kill "${signer_pid}" >/dev/null 2>&1 || true
}

trap cleanup EXIT

for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
    break
  fi
  sleep 0.2
done

curl -fsS "http://127.0.0.1:${port}/health" >/dev/null

SIGNER_URL="http://127.0.0.1:${port}" \
REGISTRY_ADDRESS="${registry_address}" \
node signer/request-signature.js
