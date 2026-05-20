// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import { DeploymentRegistry } from "../src/DeploymentRegistry.sol";

contract DeploymentRegistryTest {
    DeploymentRegistry private registry;

    bytes32 private constant DEPLOYMENT_ID = keccak256("blockops:deployment:1");
    bytes32 private constant SECOND_DEPLOYMENT_ID = keccak256("blockops:deployment:2");

    function testOwnerIsInitialSubmitter() external {
        registry = new DeploymentRegistry(address(this));

        assertEq(registry.owner(), address(this));
        assertTrue(registry.authorizedSubmitters(address(this)));
    }

    function testRegisterDeployment() external {
        registry = new DeploymentRegistry(address(this));

        registry.registerDeployment(DEPLOYMENT_ID, validInput());

        DeploymentRegistry.DeploymentProof memory proof = registry.getDeployment(DEPLOYMENT_ID);

        assertEq(proof.gitCommit, bytes32(uint256(1)));
        assertEq(proof.imageDigest, bytes32(uint256(2)));
        assertEq(proof.manifestHash, bytes32(uint256(3)));
        assertEq(proof.simulationHash, bytes32(uint256(4)));
        assertEq(proof.chainId, block.chainid);
        assertEq(proof.target, address(0xB10c));
        assertEq(proof.signerKeyId, "local-dev-key-v1");
        assertEq(uint256(proof.status), uint256(DeploymentRegistry.ReleaseStatus.Proposed));
        assertEq(proof.submittedBy, address(this));
        assertTrue(registry.deploymentExists(DEPLOYMENT_ID));
        assertTrue(proof.createdAt == proof.updatedAt);
    }

    function testRejectsZeroDeploymentId() external {
        registry = new DeploymentRegistry(address(this));

        try registry.registerDeployment(bytes32(0), validInput()) {
            fail("zero deployment id should revert");
        } catch (bytes memory reason) {
            assertSelector(reason, DeploymentRegistry.ZeroDeploymentId.selector);
        }
    }

    function testRejectsWrongChainId() external {
        registry = new DeploymentRegistry(address(this));

        DeploymentRegistry.DeploymentInput memory input = validInput();
        input.chainId = block.chainid + 1;

        try registry.registerDeployment(DEPLOYMENT_ID, input) {
            fail("wrong chain id should revert");
        } catch (bytes memory reason) {
            assertSelector(reason, DeploymentRegistry.InvalidChainId.selector);
        }
    }

    function testDuplicateDeploymentIdReverts() external {
        registry = new DeploymentRegistry(address(this));

        registry.registerDeployment(DEPLOYMENT_ID, validInput());

        try registry.registerDeployment(DEPLOYMENT_ID, validInput()) {
            fail("duplicate deployment registration should revert");
        } catch (bytes memory reason) {
            assertSelector(reason, DeploymentRegistry.DeploymentAlreadyExists.selector);
        }
    }

    function testUpdateStatusThroughLifecycle() external {
        registry = new DeploymentRegistry(address(this));
        registry.registerDeployment(DEPLOYMENT_ID, validInput());

        registry.updateStatus(DEPLOYMENT_ID, DeploymentRegistry.ReleaseStatus.Deployed);
        assertStatus(DEPLOYMENT_ID, DeploymentRegistry.ReleaseStatus.Deployed);

        registry.updateStatus(DEPLOYMENT_ID, DeploymentRegistry.ReleaseStatus.Verified);
        assertStatus(DEPLOYMENT_ID, DeploymentRegistry.ReleaseStatus.Verified);

        registry.updateStatus(DEPLOYMENT_ID, DeploymentRegistry.ReleaseStatus.Revoked);
        assertStatus(DEPLOYMENT_ID, DeploymentRegistry.ReleaseStatus.Revoked);
    }

    function testRejectsUnknownStatus() external {
        registry = new DeploymentRegistry(address(this));
        registry.registerDeployment(DEPLOYMENT_ID, validInput());

        try registry.updateStatus(DEPLOYMENT_ID, DeploymentRegistry.ReleaseStatus.Unknown) {
            fail("unknown status should revert");
        } catch (bytes memory reason) {
            assertSelector(reason, DeploymentRegistry.InvalidStatus.selector);
        }
    }

    function testRejectsStatusUpdateForMissingDeployment() external {
        registry = new DeploymentRegistry(address(this));

        try registry.updateStatus(DEPLOYMENT_ID, DeploymentRegistry.ReleaseStatus.Verified) {
            fail("missing deployment status update should revert");
        } catch (bytes memory reason) {
            assertSelector(reason, DeploymentRegistry.DeploymentNotFound.selector);
        }
    }

    function testUnauthorizedSubmitterReverts() external {
        registry = new DeploymentRegistry(address(0xA11CE));

        try registry.registerDeployment(DEPLOYMENT_ID, validInput()) {
            fail("unauthorized submitter should revert");
        } catch (bytes memory reason) {
            assertSelector(reason, DeploymentRegistry.NotSubmitter.selector);
        }
    }

    function testOwnerCanAuthorizeSubmitter() external {
        registry = new DeploymentRegistry(address(this));

        registry.setSubmitter(address(0xB0B), true);

        assertTrue(registry.authorizedSubmitters(address(0xB0B)));
    }

    function testAuthorizedSubmitterCanRegisterDeployment() external {
        registry = new DeploymentRegistry(address(this));
        RegistryCaller submitter = new RegistryCaller();

        registry.setSubmitter(address(submitter), true);
        submitter.register(registry, DEPLOYMENT_ID, validInput());

        DeploymentRegistry.DeploymentProof memory proof = registry.getDeployment(DEPLOYMENT_ID);
        assertEq(proof.submittedBy, address(submitter));
    }

    function testRevokedSubmitterCannotRegisterDeployment() external {
        registry = new DeploymentRegistry(address(this));
        RegistryCaller submitter = new RegistryCaller();

        registry.setSubmitter(address(submitter), true);
        submitter.register(registry, DEPLOYMENT_ID, validInput());

        registry.setSubmitter(address(submitter), false);

        try submitter.register(registry, SECOND_DEPLOYMENT_ID, validInput()) {
            fail("revoked submitter should revert");
        } catch (bytes memory reason) {
            assertSelector(reason, DeploymentRegistry.NotSubmitter.selector);
        }
    }

    function testOnlyOwnerCanAuthorizeSubmitter() external {
        registry = new DeploymentRegistry(address(this));
        RegistryCaller caller = new RegistryCaller();

        try caller.setSubmitter(registry, address(0xB0B), true) {
            fail("non-owner submitter update should revert");
        } catch (bytes memory reason) {
            assertSelector(reason, DeploymentRegistry.NotOwner.selector);
        }
    }

    function validInput() private view returns (DeploymentRegistry.DeploymentInput memory) {
        return DeploymentRegistry.DeploymentInput({
            gitCommit: bytes32(uint256(1)),
            imageDigest: bytes32(uint256(2)),
            manifestHash: bytes32(uint256(3)),
            simulationHash: bytes32(uint256(4)),
            chainId: block.chainid,
            target: address(0xB10c),
            signerKeyId: "local-dev-key-v1"
        });
    }

    function assertStatus(bytes32 deploymentId, DeploymentRegistry.ReleaseStatus expected) private view {
        DeploymentRegistry.DeploymentProof memory proof = registry.getDeployment(deploymentId);

        assertEq(uint256(proof.status), uint256(expected));
    }

    function assertSelector(bytes memory reason, bytes4 expected) private pure {
        assertTrue(reason.length >= 4);

        bytes4 actual;

        assembly {
            actual := mload(add(reason, 32))
        }

        if (actual != expected) {
            revert("selector assertion failed");
        }
    }

    function assertTrue(bool value) private pure {
        if (!value) {
            revert("assertTrue failed");
        }
    }

    function assertEq(address actual, address expected) private pure {
        if (actual != expected) {
            revert("address assertion failed");
        }
    }

    function assertEq(bytes32 actual, bytes32 expected) private pure {
        if (actual != expected) {
            revert("bytes32 assertion failed");
        }
    }

    function assertEq(uint256 actual, uint256 expected) private pure {
        if (actual != expected) {
            revert("uint256 assertion failed");
        }
    }

    function assertEq(uint64 actual, uint64 expected) private pure {
        if (actual != expected) {
            revert("uint64 assertion failed");
        }
    }

    function assertEq(string memory actual, string memory expected) private pure {
        if (keccak256(bytes(actual)) != keccak256(bytes(expected))) {
            revert("string assertion failed");
        }
    }

    function fail(string memory message) private pure {
        revert(message);
    }
}

contract RegistryCaller {
    function register(
        DeploymentRegistry registry,
        bytes32 deploymentId,
        DeploymentRegistry.DeploymentInput memory input
    ) external {
        registry.registerDeployment(deploymentId, input);
    }

    function setSubmitter(DeploymentRegistry registry, address submitter, bool authorized) external {
        registry.setSubmitter(submitter, authorized);
    }
}
