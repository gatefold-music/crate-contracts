// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

abstract contract ICrate is ERC165 {
    /*
     *
     * EVENTS
     *
     */ 
    event Application(bytes32 indexed recordHash, uint deposit, string data, address indexed applicant, uint applicationExpiry, bool isPrivate);
    event RecordAdded(bytes32 indexed recordHash, uint deposit, string data, address indexed applicant, uint listExpiry, bool isPrivate);
    event Challenge(bytes32 indexed recordHash, uint challengeId, address indexed challenger);
    event ChallengeFailed(bytes32 indexed recordHash, uint indexed challengeId, uint rewardPool, address winner);
    event ChallengeSucceeded(bytes32 indexed recordHash);
    event ApplicationRemoved(bytes32 indexed recordHash);
    event RecordRemoved(bytes32 indexed recordHash);
    event SortOrderUpdated(bytes32 indexed recordHash, bytes32 prevRecordHash);
    event SortOrderRemoved(bytes32 indexed recordHash);

    function propose(bytes32 _recordHash, uint _amount, string memory _data, bytes memory _signature, bool isPrivate) public virtual;

    function challenge(bytes32 _recordHash, uint _amount, address _payoutAddress) external virtual returns (uint challengeID);

    function resolveChallenge(bytes32 _recordHash) public virtual;

    function resolveApplication(bytes32 _recordHash) public virtual;

    function removeRecord(bytes32 _recordHash) public virtual;
}