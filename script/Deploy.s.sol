// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DeploymentRegistry } from "../src/DeploymentRegistry.sol";

interface Vm {
    function envAddress(string calldata name) external view returns (address);
    function startBroadcast() external;
    function stopBroadcast() external;
}

contract Deploy {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    function run() external returns (DeploymentRegistry registry) {
        address owner = vm.envAddress("BLOCKOPS_OWNER");

        vm.startBroadcast();
        registry = new DeploymentRegistry(owner);
        vm.stopBroadcast();
    }
}
