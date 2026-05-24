// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

/// @title FuelGuardRecord
/// @notice Records fuel arrivals and stores the shared data used by the other contracts.
contract FuelGuardRecord {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant IMPORTER_ROLE = keccak256("IMPORTER_ROLE");
    bytes32 public constant WHOLESALER_ROLE = keccak256("WHOLESALER_ROLE");
    bytes32 public constant RETAILER_ROLE = keccak256("RETAILER_ROLE");
    bytes32 public constant REGULATOR_ROLE = keccak256("REGULATOR_ROLE");

    enum BatchState {
        Recorded,
        AllocatedToWholesaler,
        InTransitToRetailer,
        Delivered
    }

    struct FuelBatch {
        uint256 batchId;
        uint256 parentBatchId;
        string fuelType;
        uint256 volumeLitres;
        uint256 remainingVolumeLitres;
        uint256 dateRecorded;
        string portLocation;
        address currentCustodian;
        BatchState state;
    }

    struct BatchHistory {
        string action;
        address actor;
        address from;
        address to;
        uint256 volumeLitres;
        uint256 timestamp;
    }

    address public admin;
    address public allocationContract;
    uint256 private nextBatchId = 1;

    mapping(address => mapping(bytes32 => bool)) public roles;
    mapping(uint256 => FuelBatch) private batches;
    mapping(uint256 => BatchHistory[]) private batchHistories;
    mapping(address => uint256[]) private stakeholderBatches;

    event RoleGranted(address indexed account, bytes32 indexed role);
    event AllocationContractSet(address indexed allocationContract);
    event FuelBatchRecorded(uint256 indexed batchId, address indexed importer, string fuelType, uint256 volumeLitres);
    event BatchTransferred(uint256 indexed fromBatchId, uint256 indexed newBatchId, address indexed to, uint256 volumeLitres);
    event DeliveryRecorded(uint256 indexed batchId, address indexed retailer);

    modifier onlyAdmin() {
        require(msg.sender == admin, "FuelGuard: only admin can execute this");
        _;
    }

    modifier onlyRole(bytes32 role) {
        require(roles[msg.sender][role], "FuelGuard: incorrect role to execute this");
        _;
    }

    modifier onlyAllocationContract() {
        require(msg.sender == allocationContract, "FuelGuard: only on allocation contract can this be executed");
        _;
    }

    modifier existingBatch(uint256 batchId) {
        require(batches[batchId].batchId != 0, "FuelGuard: batch does not exist");
        _;
    }

    constructor() {
        admin = msg.sender;
        roles[msg.sender][ADMIN_ROLE] = true;
        emit RoleGranted(msg.sender, ADMIN_ROLE);
    }

    function grantRole(address account, bytes32 role) external onlyAdmin {
        require(account != address(0), "FuelGuard: zero address");
        roles[account][role] = true;
        emit RoleGranted(account, role);
    }

    function setAllocationContract(address contractAddress) external onlyAdmin {
        require(contractAddress != address(0), "FuelGuard: zero address");
        allocationContract = contractAddress;
        emit AllocationContractSet(contractAddress);
    }

    // Importers record new fuel arrivals.
    function recordFuelBatch(
        string calldata fuelType,
        uint256 volumeLitres,
        string calldata portLocation
    ) external onlyRole(IMPORTER_ROLE) returns (uint256 batchId) {
        require(volumeLitres > 0, "FuelGuard: volume must be greater than zero");
        require(bytes(fuelType).length > 0, "FuelGuard: fuel type required");
        require(bytes(portLocation).length > 0, "FuelGuard: port location required");

        batchId = nextBatchId;
        nextBatchId++;

        batches[batchId] = FuelBatch({
            batchId: batchId,
            parentBatchId: 0,
            fuelType: fuelType,
            volumeLitres: volumeLitres,
            remainingVolumeLitres: volumeLitres,
            dateRecorded: block.timestamp,
            portLocation: portLocation,
            currentCustodian: msg.sender,
            state: BatchState.Recorded
        });

        stakeholderBatches[msg.sender].push(batchId);
        _addHistory(batchId, "RECORDED", msg.sender, address(0), msg.sender, volumeLitres);

        emit FuelBatchRecorded(batchId, msg.sender, fuelType, volumeLitres);
    }

    // called by FuelGuardAllocation to split and transfer fuel to the next stakeholder.
    function createChildBatch(
        uint256 parentBatchId,
        address actor,
        address receiver,
        uint256 volumeLitres,
        BatchState newState,
        string calldata action
    ) external onlyAllocationContract existingBatch(parentBatchId) returns (uint256 newBatchId) {
        FuelBatch storage parent = batches[parentBatchId];

        require(parent.currentCustodian == actor, "FuelGuard: You are not the custodian");
        require(volumeLitres > 0, "FuelGuard: volume must be greater than zero");
        require(parent.remainingVolumeLitres >= volumeLitres, "FuelGuard: not enough fuel remaining");

        if (newState == BatchState.AllocatedToWholesaler) {
            require(parent.state == BatchState.Recorded, "FuelGuard: parent must be recorded");
        } else if (newState == BatchState.InTransitToRetailer) {
            require(parent.state == BatchState.AllocatedToWholesaler, "FuelGuard: parent must be wholesaler stock");
        } else {
            revert("FuelGuard: invalid transfer state");
        }

        parent.remainingVolumeLitres -= volumeLitres;

        newBatchId = nextBatchId;
        nextBatchId++;

        batches[newBatchId] = FuelBatch({
            batchId: newBatchId,
            parentBatchId: parentBatchId,
            fuelType: parent.fuelType,
            volumeLitres: volumeLitres,
            remainingVolumeLitres: volumeLitres,
            dateRecorded: block.timestamp,
            portLocation: parent.portLocation,
            currentCustodian: receiver,
            state: newState
        });

        stakeholderBatches[receiver].push(newBatchId);
        _addHistory(parentBatchId, action, actor, actor, receiver, volumeLitres);
        _addHistory(newBatchId, action, actor, actor, receiver, volumeLitres);

        emit BatchTransferred(parentBatchId, newBatchId, receiver, volumeLitres);
    }

    // called by FuelGuardAllocation when the retailer confirms delivery.
    function markDelivered(uint256 batchId, address retailer)
        external
        onlyAllocationContract
        existingBatch(batchId)
    {
        FuelBatch storage batch = batches[batchId];

        require(batch.currentCustodian == retailer, "FuelGuard: you are not retailer");
        require(batch.state == BatchState.InTransitToRetailer, "FuelGuard: batch is not in transit");

        batch.state = BatchState.Delivered;
        _addHistory(batchId, "DELIVERED", retailer, address(0), retailer, batch.volumeLitres);

        emit DeliveryRecorded(batchId, retailer);
    }

    function getBatchDetails(uint256 batchId) external view existingBatch(batchId) returns (FuelBatch memory) {
        return batches[batchId];
    }

    function getBatchHistory(uint256 batchId) external view existingBatch(batchId) returns (BatchHistory[] memory) {
        return batchHistories[batchId];
    }

    function getCurrentHoldings(address stakeholder) external view returns (uint256[] memory) {
        uint256[] storage allIds = stakeholderBatches[stakeholder];
        uint256 count = 0;

        for (uint256 i = 0; i < allIds.length; i++) {
            if (batches[allIds[i]].remainingVolumeLitres > 0 && batches[allIds[i]].currentCustodian == stakeholder) {
                count++;
            }
        }

        uint256[] memory holdings = new uint256[](count);
        uint256 index = 0;

        for (uint256 i = 0; i < allIds.length; i++) {
            if (batches[allIds[i]].remainingVolumeLitres > 0 && batches[allIds[i]].currentCustodian == stakeholder) {
                holdings[index] = allIds[i];
                index++;
            }
        }

        return holdings;
    }

    function _addHistory(
        uint256 batchId,
        string memory action,
        address actor,
        address from,
        address to,
        uint256 volumeLitres
    ) private {
        batchHistories[batchId].push(BatchHistory({
            action: action,
            actor: actor,
            from: from,
            to: to,
            volumeLitres: volumeLitres,
            timestamp: block.timestamp
        }));
    }
}

// FuelGuardAllocation contract
// handles fuel movement between importer, wholesaler, and retailer.
contract FuelGuardAllocation {
    FuelGuardRecord public record;

    event AllocatedToWholesaler(uint256 indexed fromBatchId, uint256 indexed newBatchId, address indexed wholesaler);
    event DistributedToRetailer(uint256 indexed fromBatchId, uint256 indexed newBatchId, address indexed retailer);
    event DeliveryConfirmed(uint256 indexed batchId, address indexed retailer);

    constructor(address recordAddress) {
        require(recordAddress != address(0), "FuelGuard: zero address");
        record = FuelGuardRecord(recordAddress);
    }

    function allocateToWholesaler(
        uint256 batchId,
        address wholesaler,
        uint256 volumeLitres
    ) external returns (uint256 newBatchId) {
        require(record.roles(msg.sender, record.IMPORTER_ROLE()), "FuelGuard: only importer can execute this");
        require(record.roles(wholesaler, record.WHOLESALER_ROLE()), "FuelGuard: receiver is not wholesaler");

        newBatchId = record.createChildBatch(
            batchId,
            msg.sender,
            wholesaler,
            volumeLitres,
            FuelGuardRecord.BatchState.AllocatedToWholesaler,
            "ALLOCATED_TO_WHOLESALER"
        );

        emit AllocatedToWholesaler(batchId, newBatchId, wholesaler);
    }

    function distributeToRetailer(
        uint256 batchId,
        address retailer,
        uint256 volumeLitres
    ) external returns (uint256 newBatchId) {
        require(record.roles(msg.sender, record.WHOLESALER_ROLE()), "FuelGuard: only wholesaler can execute this");
        require(record.roles(retailer, record.RETAILER_ROLE()), "FuelGuard: receiver is not retailer");

        newBatchId = record.createChildBatch(
            batchId,
            msg.sender,
            retailer,
            volumeLitres,
            FuelGuardRecord.BatchState.InTransitToRetailer,
            "DISTRIBUTED_TO_RETAILER"
        );

        emit DistributedToRetailer(batchId, newBatchId, retailer);
    }

    function confirmDelivery(uint256 batchId) external {
        require(record.roles(msg.sender, record.RETAILER_ROLE()), "FuelGuard: only retailer");

        record.markDelivered(batchId, msg.sender);

        emit DeliveryConfirmed(batchId, msg.sender);
    }
}

// FuelGuardVerification contract
// read only contract to read public information
contract FuelGuardVerification {
    FuelGuardRecord public record;

    constructor(address recordAddress) {
        require(recordAddress != address(0), "FuelGuard: zero address");
        record = FuelGuardRecord(recordAddress);
    }

    function getBatchDetails(uint256 batchId) external view returns (FuelGuardRecord.FuelBatch memory) {
        return record.getBatchDetails(batchId);
    }

    function getBatchHistory(uint256 batchId) external view returns (FuelGuardRecord.BatchHistory[] memory) {
        return record.getBatchHistory(batchId);
    }

    function getCurrentHoldings(address stakeholder) external view returns (uint256[] memory) {
        return record.getCurrentHoldings(stakeholder);
    }
}
