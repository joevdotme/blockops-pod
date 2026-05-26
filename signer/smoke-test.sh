#!/usr/bin/env bash
set -euo pipefail

export PATH="${HOME}/.cargo/bin:${HOME}/.foundry/bin:${PATH}"

port="${SIGNER_PORT:-8787}"
registry_address="${REGISTRY_ADDRESS:-0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266}"
log_file="/tmp/blockops-local-signer.log"
zero_private_key="0x0000000000000000000000000000000000000000000000000000000000000000"

if ! command -v cast >/dev/null; then
  echo "cast not found on PATH. Install Foundry or update PATH." >&2
  exit 1
fi

if [[ "${SIGNER_PRIVATE_KEY:-}" == "" || "${SIGNER_PRIVATE_KEY:-}" == "${zero_private_key}" ]]; then
  echo "SIGNER_PRIVATE_KEY is missing or still set to the zero placeholder." >&2
  exit 1
fi

SIGNER_PORT="${port}" node signer/local-signer.js > "${log_file}" 2>&1 &
signer_pid="$!"

cleanup() {
  kill "${signer_pid}" >/dev/null 2>&1 || true
}

trap cleanup EXIT

for _ in $(seq 1 50); do
  if curl -fsS "http://127.0.0.1:${port}/health" >/dev/null 2>&1; then
    break
  fi

  if ! kill -0 "${signer_pid}" >/dev/null 2>&1; then
    echo "local signer exited before becoming healthy" >&2
    cat "${log_file}" >&2 || true
    exit 1
  fi

  sleep 0.2
done

if ! curl -fsS "http://127.0.0.1:${port}/health" >/dev/null; then
  echo "local signer did not become healthy" >&2
  cat "${log_file}" >&2 || true
  exit 1
fi

SIGNER_URL="http://127.0.0.1:${port}" \
REGISTRY_ADDRESS="${registry_address}" \
node signer/request-signature.js
