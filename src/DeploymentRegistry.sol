// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title DeploymentRegistry
/// @notice Records immutable deployment metadata and status transitions for BlockOps releases.
contract DeploymentRegistry {
    enum ReleaseStatus {
        Unknown,
        Proposed,
        Deployed,
        Verified,
        Revoked
    }

    struct DeploymentInput {
        bytes32 gitCommit;
        bytes32 imageDigest;
        bytes32 manifestHash;
        bytes32 simulationHash;
        uint256 chainId;
        address target;
        string signerKeyId;
    }

    struct DeploymentProof {
        bytes32 gitCommit;
        bytes32 imageDigest;
        bytes32 manifestHash;
        bytes32 simulationHash;
        uint256 chainId;
        address target;
        string signerKeyId;
        ReleaseStatus status;
        address submittedBy;
        uint64 createdAt;
        uint64 updatedAt;
    }

    error NotOwner(address caller);
    error NotSubmitter(address caller);
    error ZeroDeploymentId();
    error DeploymentAlreadyExists(bytes32 deploymentId);
    error DeploymentNotFound(bytes32 deploymentId);
    error InvalidChainId(uint256 expected, uint256 actual);
    error InvalidStatus(ReleaseStatus status);
    error ZeroAddress();

    event SubmitterUpdated(address indexed submitter, bool authorized);
    event DeploymentRegistered(
        bytes32 indexed deploymentId,
        bytes32 indexed gitCommit,
        uint256 indexed chainId,
        address target,
        bytes32 imageDigest,
        bytes32 manifestHash,
        bytes32 simulationHash,
        string signerKeyId,
        address submittedBy
    );
    event DeploymentStatusUpdated(
        bytes32 indexed deploymentId,
        ReleaseStatus previousStatus,
        ReleaseStatus newStatus,
        address updatedBy
    );

    address public owner;

    mapping(address submitter => bool authorized) public authorizedSubmitters;
    mapping(bytes32 deploymentId => bool registered) public deploymentRegistered;
    mapping(bytes32 deploymentId => DeploymentProof proof) private deployments;

    modifier onlyOwner() {
        if (msg.sender != owner) {
            revert NotOwner(msg.sender);
        }
        _;
    }

    modifier onlySubmitter() {
        if (!authorizedSubmitters[msg.sender]) {
            revert NotSubmitter(msg.sender);
        }
        _;
    }

    constructor(address initialOwner) {
        if (initialOwner == address(0)) {
            revert ZeroAddress();
        }

        owner = initialOwner;
        authorizedSubmitters[initialOwner] = true;

        emit SubmitterUpdated(initialOwner, true);
    }

    function transferOwnership(address newOwner) external onlyOwner {
        if (newOwner == address(0)) {
            revert ZeroAddress();
        }

        owner = newOwner;
    }

    function setSubmitter(address submitter, bool authorized) external onlyOwner {
        if (submitter == address(0)) {
            revert ZeroAddress();
        }

        authorizedSubmitters[submitter] = authorized;

        emit SubmitterUpdated(submitter, authorized);
    }

    function registerDeployment(bytes32 deploymentId, DeploymentInput calldata input)
        external
        onlySubmitter
    {
        if (deploymentId == bytes32(0)) {
            revert ZeroDeploymentId();
        }
        if (deploymentRegistered[deploymentId]) {
            revert DeploymentAlreadyExists(deploymentId);
        }
        if (input.chainId != block.chainid) {
            revert InvalidChainId(block.chainid, input.chainId);
        }

        uint64 timestamp = uint64(block.timestamp);

        deploymentRegistered[deploymentId] = true;
        deployments[deploymentId] = DeploymentProof({
            gitCommit: input.gitCommit,
            imageDigest: input.imageDigest,
            manifestHash: input.manifestHash,
            simulationHash: input.simulationHash,
            chainId: input.chainId,
            target: input.target,
            signerKeyId: input.signerKeyId,
            status: ReleaseStatus.Proposed,
            submittedBy: msg.sender,
            createdAt: timestamp,
            updatedAt: timestamp
        });

        emit DeploymentRegistered(
            deploymentId,
            input.gitCommit,
            input.chainId,
            input.target,
            input.imageDigest,
            input.manifestHash,
            input.simulationHash,
            input.signerKeyId,
            msg.sender
        );
    }

    function updateStatus(bytes32 deploymentId, ReleaseStatus newStatus) external onlySubmitter {
        DeploymentProof storage proof = deployments[deploymentId];

        if (!deploymentRegistered[deploymentId]) {
            revert DeploymentNotFound(deploymentId);
        }
        if (newStatus == ReleaseStatus.Unknown) {
            revert InvalidStatus(newStatus);
        }

        ReleaseStatus previousStatus = proof.status;
        proof.status = newStatus;
        proof.updatedAt = uint64(block.timestamp);

        emit DeploymentStatusUpdated(deploymentId, previousStatus, newStatus, msg.sender);
    }

    function getDeployment(bytes32 deploymentId)
        external
        view
        returns (DeploymentProof memory proof)
    {
        proof = deployments[deploymentId];

        if (!deploymentRegistered[deploymentId]) {
            revert DeploymentNotFound(deploymentId);
        }
    }

    function deploymentExists(bytes32 deploymentId) external view returns (bool) {
        return deploymentRegistered[deploymentId];
    }
}
