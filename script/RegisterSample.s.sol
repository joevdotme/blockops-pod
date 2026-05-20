// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DeploymentRegistry } from "../src/DeploymentRegistry.sol";

interface RegisterSampleVm {
    function envAddress(string calldata name) external view returns (address);
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract RegisterSample {
    RegisterSampleVm private constant vm =
        RegisterSampleVm(address(uint160(uint256(keccak256("hevm cheat code")))));

    bytes32 private constant SAMPLE_DEPLOYMENT_ID =
        0x256e3700d6f85b512d2c84d37bbb728099732d920ee341bf8f93ddbbe6c3c191;

    function run() external {
        DeploymentRegistry registry = DeploymentRegistry(vm.envAddress("REGISTRY_ADDRESS"));

        DeploymentRegistry.DeploymentInput memory input = DeploymentRegistry.DeploymentInput({
            gitCommit: bytes32(uint256(1)),
            imageDigest: keccak256("ghcr.io/joev/blockops-pod@sha256:local"),
            manifestHash: keccak256("deployments/local/manifest.json"),
            simulationHash: keccak256("simulations/local/report.json"),
            chainId: block.chainid,
            target: address(registry),
            signerKeyId: "anvil-account-0"
        });

        vm.startBroadcast();
        registry.registerDeployment(SAMPLE_DEPLOYMENT_ID, input);
        vm.stopBroadcast();
    }
}
