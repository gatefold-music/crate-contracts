// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IAffinityManager} from "../interfaces/IAffinityManager.sol";
import {ICrate} from "../interfaces/ICrate.sol";
import {IERC20} from "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import {OwnableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/PausableUpgradeable.sol";
import {PollRegistry} from "../poll/PollRegistry.sol";
import {ReentrancyGuardUpgradeable} from "openzeppelin-contracts-upgradeable/contracts/utils/ReentrancyGuardUpgradeable.sol";
import {Oracle} from "../utils/VerifySignature.sol";

contract Crate is 
    IAffinityManager, 
    ICrate,
    Oracle, 
    OwnableUpgradeable, 
    PausableUpgradeable,
    ReentrancyGuardUpgradeable
{ 
    string public crateInfo;
    uint public minDeposit;
    uint public appDuration;
    uint public listDuration;
    address public tokenAddress;
    address public pollRegistryAddress;
    bool public isSealed;
    bool public isSortable;
    uint256 public listLength; 
    uint256 public maxListLength;
    address public verifierAddress;
    
    /*
     *
     * STRUCTS
     *
     */
    struct Record {
        uint applicationExpiry; // Expiration date of apply stage
        bool listed;            // Indicates registry status
        address owner;          // Owner of record
        uint challengeId;       // the challenge id of the current challenge
        uint deposit;           // Number of tokens staked for this record
        string data;            // id or ipfs hash. 
        address challenger;     // challenger address
        uint challengeDeposit;  // challenge deposit amount
        address challengerPayoutAddress; // address to send payout or refund (if empty address, defaults to challenger address)
        bool resolved;          // true if record has been challenged and voting has closed
        uint listingExpiry;     // zero if no expiration, otherwise record expire time
        bool doesExist;        // for validating if a record exists;
        address tokenAddress;   // token address for this record 
        address oracleAddress;   // oracle address for private listing. zero address if public
        bool isPrivate;
        bool isWithdrawn;
    }

    struct Position {
        bytes32 prev;
        bytes32 next;
    }
    
    /*
     *
     * Mappings
     *
     */
    mapping(bytes32 => Record) private records; // This mapping holds the listings and applications for this list
    mapping(bytes32 => Position) public positions; // Mapping to maintain sort order

    function initialize(string memory _crateInfo, address _token, address _voting, uint _minDeposit, address _owner) public initializer {
        require(_token != address(0), "Token address should not be zero address");
        tokenAddress = _token;
        pollRegistryAddress = _voting;
        crateInfo = _crateInfo;
        minDeposit = _minDeposit;
        appDuration = 0; // no application period
        listDuration = 0; // no listing period
        listLength = 0;
        maxListLength = type(uint256).max;
        __Ownable_init(_owner);
        __Pausable_init();
        __ReentrancyGuard_init();
    }

    /*
     *
     * MODIFIERS
     *
     */

    modifier verifyOracle(bytes32 _recordHash, string memory _data, bytes memory _signature) {
        if (verifierAddress != address(0)) {
            bytes32 message = keccak256(abi.encode(_recordHash, _data));
            require(verifySignature(message, _signature, verifierAddress), "Invalid oracle signature"); // verify signature 
        }
        _;
    }

    modifier crateIsNotSealed() {
        require(!isSealed, "Crate has been sealed close");
        _;
    }

    modifier crateIsSealed() {
        require(isSealed, "Crate must be sealed closed");
        _;
    }

    modifier sufficientBalance(uint _amount, address _sender) {
        require(IERC20(tokenAddress).balanceOf(_sender) >= _amount, "Insufficient token balance");
        _;
    }

    modifier verifyMinDeposit(uint _amount) {
        require(_amount >= minDeposit, "Amount does not meet crate minimum");
        _;
    }

    modifier doesNotExist(bytes32 _hash) {
        require(!records[_hash].doesExist, "Record already exists");
        _;
    }

    modifier crateNotFull(uint newListingCount) {
        bool isBeingListed = appDuration == 0 ? true : false;
        require(!isBeingListed || listLength + newListingCount<= maxListLength, "Exceeds max length"); 
        _;
    }

    modifier isRecordOwner(bytes32 _hash, address _sender) {
        require(records[_hash].owner == _sender, "Sender is not record owner"); 
        _;
    }

    modifier doesExist(bytes32 _hash) {
        require(records[_hash].doesExist, "Record does not exist");
        _;
    }

    modifier unchallenged(bytes32 _hash) {
        require(records[_hash].challengeId == 0 || (records[_hash].challengeId > 0 && records[_hash].resolved == true), "Record is in challenged state");
        _;
    }

    /*
     *
     * CORE
     *
     */ 

    /*
     * @dev Propose a record to add to this crate
     * @notice If no app duration set, app state is skipped and record will be automatically allowlisted
     * @param _recordHash keccak256 hash of record identifier
     * @param _amount the amount of tokens to stake for this record (must be at least minimum deposit)
     * @param _data metadata string or uri 
     */
    function propose(bytes32 _recordHash, uint _amount, string memory _data, bytes memory _signature, bool isPrivate) 
        public 
        override
        crateIsNotSealed
        whenNotPaused
        verifyOracle(_recordHash, _data, _signature) 
        verifyMinDeposit(_amount)
        doesNotExist(_recordHash)
        sufficientBalance(_amount, msg.sender) 
    {   
        bool isBeingListed = appDuration == 0 ? true : false;
        require(!isBeingListed || listLength + 1 <= maxListLength, "Exceeds max length"); 
        require(!isBeingListed || IERC20(tokenAddress).transferFrom(msg.sender, address(this), _amount), "Tokens failed to transfer.");

        _add(_recordHash, _amount, _data, msg.sender, isBeingListed, isPrivate);
    }

    function revealProposal(bytes32 _secretHash, bytes32 _recordHash, string memory _data, bytes memory _signature) 
        public
        doesExist(_secretHash)
        doesNotExist(_recordHash)
        isRecordOwner(_secretHash, msg.sender)
        unchallenged(_secretHash)
    {   
        Record memory record = records[_secretHash];
        require(record.isPrivate ,"Listing is not private");

        bytes32 message = keccak256(abi.encode(_secretHash, _recordHash));
        require(verifySignature(message, _signature, record.oracleAddress), "Invalid oracle signature"); // verify signature 

        _remove(_secretHash);

        _add(_recordHash, record.deposit, _data, record.owner, record.listed, false);
    }

    /*
     * @dev Challenge a record or application
     * @notice Triggers a new poll for token holders to settle dispute
     * @param _recordHash keccak256 hash of record identifier
     * @param _amount the amount of tokens to stake for this record (must be at least the staked amount for record)
     */
    function challenge(bytes32 _recordHash, uint _amount, address _payoutAddress) 
        external
        override
        crateIsNotSealed
        whenNotPaused
        doesExist(_recordHash)
        returns (uint challengeID) {

        Record storage record = records[_recordHash];
        require(IERC20(record.tokenAddress).balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        require(_amount >= record.deposit, "Not enough stake for application.");
        require(record.challengeId == 0, "Record has already been challenged.");

        address payoutAddress = _payoutAddress != address(0) ? _payoutAddress : msg.sender;

        uint newPollId = PollRegistry(pollRegistryAddress).createPoll(record.tokenAddress, record.owner, payoutAddress);
        record.challengeId = newPollId;
        record.challenger = msg.sender;
        record.challengerPayoutAddress = payoutAddress;
        record.challengeDeposit += _amount;

        require(IERC20(record.tokenAddress).transferFrom(msg.sender, address(this), _amount), "Tokens failed to transfer.");

        emit Challenge(_recordHash, newPollId, msg.sender);

        return newPollId;
    }

    /*
     * @dev Resolve challenge once voting has completed
     * @notice If list length has been reached, winning address can still call this but adding entry to list will be skipped
     * @param _recordHash keccak256 hash of record identifier
     */
    function resolveChallenge(bytes32 _recordHash) public override doesExist(_recordHash) {
        Record storage record = records[_recordHash];
        require(record.challengeId > 0 && record.resolved == false, "Has no open challenge");
        PollRegistry pr = PollRegistry(pollRegistryAddress);
        require(pr.hasResolved(record.challengeId) || pr.canResolve(record.challengeId), "Poll is still active");

        if (!pr.hasResolved(record.challengeId)) {
            pr.resolvePoll(record.challengeId);
        }

        bool challengeFailed = pr.hasPassed(record.challengeId);
        uint256 newDepositAmount = record.challengeDeposit + record.deposit;

        record.resolved = true;

        if(challengeFailed) {
            emit ChallengeFailed(_recordHash, record.challengeId, record.challengeDeposit, record.owner);
            record.deposit = newDepositAmount;
            record.challengeDeposit = 0; 

            // if space on list, update application to listed
            // if skipped, resolveApplication can be called when space has been opened up
            if(!record.listed && listLength + 1 <= maxListLength) {
                uint listingExpiry = listDuration > 0 ? block.timestamp + listDuration : 0;
                record.listingExpiry = listingExpiry;
                record.listed = true;
                listLength += 1;
                emit RecordAdded(_recordHash, record.deposit, record.data, record.owner, listingExpiry, record.isPrivate);
            }
        } else { 
            require(IERC20(record.tokenAddress).transfer(record.challengerPayoutAddress, newDepositAmount), "Token transfer failed");
            emit ChallengeSucceeded(_recordHash);
            _remove(_recordHash);
        }
    }

    /*
     * @dev Allowlist an application if application time has expired
     * @notice record applicationExpiry should not be zero
     * @param _recordHash keccak256 hash of record identifier
     */
    function resolveApplication(bytes32 _recordHash) public override doesExist(_recordHash) unchallenged(_recordHash) {
        Record storage record = records[_recordHash];
        require(!record.listed, "Record already allow listed");
        require(record.applicationExpiry > 0 && block.timestamp > record.applicationExpiry, "Application duration has not expired");
        require(listLength + 1 <= maxListLength, "Exceeds max length"); 
        
        record.listed = true;
        uint listingExpiry = listDuration > 0 ? block.timestamp + listDuration : 0;
        record.listingExpiry = listingExpiry;
        emit RecordAdded(_recordHash, record.deposit, record.data, record.owner, listingExpiry, record.isPrivate);
    }

    /*
     * @dev Remove an owned or expired record
     * @param _recordHash keccak256 hash of record identifier
     */
    function removeRecord(bytes32 _recordHash) public 
        override 
        crateIsNotSealed
        whenNotPaused
        doesExist(_recordHash)
        unchallenged(_recordHash) 
    {
        Record memory record = records[_recordHash];
        require(record.owner == msg.sender || (record.listingExpiry > 0 && block.timestamp > record.listingExpiry ), "Record can only be removed by owner, challenge or if expired");
        
        require(IERC20(record.tokenAddress).transferFrom(address(this), record.owner, record.deposit), "Tokens failed to transfer.");

        _remove(_recordHash);
    }

    function updatePosition(bytes32 _recordHash, bytes32 _prevHash) public {
        require(isSortable, "Sorting is disable");
        require(IERC20(tokenAddress).balanceOf(msg.sender) > 0, "Insufficient token balance");
        require(records[_recordHash].listed, "Record is not listed");
        require(positions[_prevHash].next != bytes32(0) || positions[_prevHash].prev != bytes32(0), "Previous record hash is not sorted");

        bytes32 next = positions[_prevHash].next;

        positions[_prevHash].next = _recordHash;

        positions[_recordHash].prev = _prevHash;
        positions[_recordHash].next = next;

        emit SortOrderUpdated(_recordHash, _prevHash);
    }

    function withdraw(bytes32 _recordHash) external 
        crateIsSealed
        doesExist(_recordHash)
        isRecordOwner(_recordHash, msg.sender) 
        unchallenged(_recordHash)
        nonReentrant
    {
        Record storage record = records[_recordHash];
        require(!record.isWithdrawn, "Deposit has already been withdrawn" );

        record.isWithdrawn = true;
        require(IERC20(record.tokenAddress).transferFrom(address(this), record.owner, record.deposit), "Tokens failed to transfer.");
    }

    /*
     *
     * READ
     *
     */ 
    function isRecordListed(bytes32 _recordHash) public view returns (bool listed, address owner) {
        return (records[_recordHash].listed, records[_recordHash].owner);
    }

    function getRecord(bytes32 _recordHash) public view returns (Record memory record) {
        return records[_recordHash];
    }

    /*
     *
     * ADMIN
     *
     */   

    /*
     * @dev sets crate metadata uri
     */
    function updateCrateInfo(string memory _crateInfo) public onlyOwner {
        crateInfo = _crateInfo;
    }

    /*
     * @dev Updates oracle address 
     * @notice empty address skips oracle signature verification
     */
    function updateVerifier(address _verifierAddress) public onlyOwner {
        verifierAddress = _verifierAddress;
    }

    /*
     * @dev This locks the crate fooooreeeeeveer
     * @notice any pending challenges (polls) can still be resolved even after locking
     * @notice this action cannot be undone
     */
    function sealCrate() public onlyOwner {
        isSealed = true;
    }

    /*
     * @dev toggle sortability
     */
    function updateSortability(bool _sortable) public onlyOwner {
        isSortable = _sortable;
    }

    /*
     * @dev updates crate capacity
     */
    function updateMaxLength(uint256 _newListLength) public onlyOwner {
        require(_newListLength >= listLength, "Max length can not be less than current list length");
        maxListLength = _newListLength;
    }
    
    /*
     * @dev Updates the Token 
     * @notice does not account for old token balances
     * @param _token erc20 token address to use for new proposals 
     */
    function updateToken(address _token) public onlyOwner {
        tokenAddress = _token;
    }

    /*
     * @dev Updates application duration 
     * @notice if set to zero, new records will get listed instantly
     * @param _duration number of seconds until an unchallenged application can be listed
     */
    function updateAppDuration(uint _duration) public onlyOwner {
         appDuration = _duration;
    }

    /*
     * @dev Updates listing duration 
     * @notice if set to zero, record will never expire and can only be removed by owner or poll
     * @param _duration number of seconds until a record can removed by any caller
     */
    function updateListDuration(uint _duration) public onlyOwner {
         listDuration = _duration;
    }

    function setAffinity(address _affinityAddress) public onlyOwner {
         affinityAddress = _affinityAddress;
    }

    function pauseContract() external onlyOwner {
        _pause();
    }

    function unpauseContract() external onlyOwner {
        _unpause();
    }


    /*
     *
     * PRIVATE
     *
     */

     function _add(bytes32 _hash,uint _amount, string memory _data, address _sender, bool _isBeingListed, bool _isPrivate) private {
        Record storage record = records[_hash];
        record.owner = _sender;
        record.deposit = _amount;
        record.data = _data;
        record.doesExist = true;
        record.tokenAddress = tokenAddress;
        record.isPrivate = _isPrivate;
        record.oracleAddress = verifierAddress;
        

        if (_isBeingListed) {
            uint listingExpiry = listDuration > 0 ? block.timestamp + listDuration : 0;
            record.listed = true;
            listLength += 1;
            record.listingExpiry = listingExpiry;
            emit RecordAdded(_hash, _amount, _data, _sender, listingExpiry, _isPrivate);
        } else {
            record.applicationExpiry = block.timestamp + appDuration;
            emit Application(_hash, _amount, _data, _sender, record.applicationExpiry, _isPrivate);
        }
     }

    function _remove(bytes32 _hash) private {
        listLength -= 1;

        if (records[_hash].listed) {
            delete positions[_hash];
            emit RecordRemoved(_hash);
        } else {
            emit ApplicationRemoved(_hash);
        }

        delete records[_hash];
    }
}
