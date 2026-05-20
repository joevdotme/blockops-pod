#!/usr/bin/env bash
set -euo pipefail

chain="${CHAIN:-local}"
chain_id="${CHAIN_ID:-31337}"
owner="${OWNER:-0x0000000000000000000000000000000000000000}"
fork_block="${FORK_BLOCK:-}"
contract="DeploymentRegistry"
artifact="out/DeploymentRegistry.sol/DeploymentRegistry.json"
out_dir="deployments/${chain}"
manifest="${out_dir}/manifest.json"

mkdir -p "${out_dir}"

if [[ ! -f "${artifact}" ]]; then
  forge build >/dev/null
fi

git_commit="$(git rev-parse HEAD 2>/dev/null || printf 'unknown')"
git_status="clean"

if ! git diff --quiet 2>/dev/null || ! git diff --cached --quiet 2>/dev/null; then
  git_status="dirty"
fi

compiler="$(forge --version | head -n 1)"
creation_bytecode="$(forge inspect src/DeploymentRegistry.sol:DeploymentRegistry bytecode)"
runtime_bytecode="$(forge inspect src/DeploymentRegistry.sol:DeploymentRegistry deployedBytecode)"
creation_bytecode_hash="$(cast keccak "${creation_bytecode}")"
runtime_bytecode_hash="$(cast keccak "${runtime_bytecode}")"
manifest_created_at="$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
fork_block_json="null"

if [[ -n "${fork_block}" ]]; then
  fork_block_json="${fork_block}"
fi

cat > "${manifest}" <<JSON
{
  "schema": "blockops.deployment-manifest.v1",
  "createdAt": "${manifest_created_at}",
  "chain": "${chain}",
  "chainId": ${chain_id},
  "forkBlock": ${fork_block_json},
  "rpcUrl": "redacted",
  "owner": "${owner}",
  "git": {
    "commit": "${git_commit}",
    "status": "${git_status}"
  },
  "contract": {
    "name": "${contract}",
    "source": "src/DeploymentRegistry.sol",
    "artifact": "${artifact}",
    "compiler": "${compiler}",
    "creationBytecodeHash": "${creation_bytecode_hash}",
    "runtimeBytecodeHash": "${runtime_bytecode_hash}"
  },
  "release": {
    "deploymentScript": "script/Deploy.s.sol:Deploy",
    "simulationScript": "script/SimulateDeployment.s.sol:SimulateDeployment",
    "sampleDeploymentId": "0x256e3700d6f85b512d2c84d37bbb728099732d920ee341bf8f93ddbbe6c3c191"
  }
}
JSON

manifest_hash="$(cast keccak "$(cat "${manifest}")")"
printf '%s\n' "${manifest_hash}" > "${out_dir}/manifest.hash"

echo "Wrote ${manifest}"
echo "Manifest hash: ${manifest_hash}"
