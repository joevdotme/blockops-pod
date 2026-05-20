// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DeploymentRegistry } from "../src/DeploymentRegistry.sol";

interface SimulateVm {
    function envAddress(string calldata name) external view returns (address);
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract SimulateDeployment {
    SimulateVm private constant vm =
        SimulateVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant SAMPLE_DEPLOYMENT_ID =
        0x256e3700d6f85b512d2c84d37bbb728099732d920ee341bf8f93ddbbe6c3c191;

    function run() external returns (DeploymentRegistry registry, bytes32 deploymentId) {
        address owner = vm.envAddress("BLOCKOPS_OWNER");

        DeploymentRegistry.DeploymentInput memory input = DeploymentRegistry.DeploymentInput({
            gitCommit: bytes32(uint256(1)),
            imageDigest: keccak256("ghcr.io/joev/blockops-pod@sha256:simulation"),
            manifestHash: keccak256("deployments/simulation/manifest.json"),
            simulationHash: keccak256("simulations/simulation/report.json"),
            chainId: block.chainid,
            target: owner,
            signerKeyId: "simulation-key-v1"
        });

        vm.startBroadcast();
        registry = new DeploymentRegistry(owner);
        registry.registerDeployment(SAMPLE_DEPLOYMENT_ID, input);
        vm.stopBroadcast();

        deploymentId = SAMPLE_DEPLOYMENT_ID;
    }
}
