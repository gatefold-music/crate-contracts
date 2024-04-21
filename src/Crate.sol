// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {PollRegistry} from "./PollRegistry.sol";
import "openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import "./VerifySignature.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { console2} from "forge-std/Test.sol";



contract Crate is OwnableUpgradeable { 
    string public name;
    string public description;
    uint public minDeposit;
    uint public appDuration;
    uint public listDuration;
    address public tokenAddress;
    address public pollRegistryAddress;
    uint8 public constant BATCH_MAX = 51; 
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
    mapping(bytes32 => mapping(address => bool)) public privateViewers; // private record hash => viewer address => viewer can view

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

    function initialize(string memory _name, string memory _description, address _token, address _voting, uint _minDeposit, address _owner) initializer public {
        require(_token != address(0), "Token address should not be zero address");
        tokenAddress = _token;
        pollRegistryAddress = _voting;
        name = _name;
        description = _description;
        minDeposit = _minDeposit;
        appDuration = 0; // no application period
        listDuration = 0; // no listing period
        listLength = 0;
        maxListLength = type(uint256).max;
        __Ownable_init(_owner);
    }

    /*
     *
     * MODIFIERS
     *
     */
    modifier validateHash(bytes32 _hash, string memory _data) {
        require(_hash == bytes32(abi.encodePacked(_data)),  "Hash does not match data string");
        _;
    }

    modifier crateIsNotSealed() {
        require(!isSealed, "Crate has been sealed close");
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
    function propose(bytes32 _recordHash, uint _amount, string memory _data) 
        public 
        validateHash(_recordHash, _data) 
        crateIsNotSealed()
        verifyMinDeposit(_amount)
        doesNotExist(_recordHash)
        sufficientBalance(_amount, msg.sender) 
    {
        bool isBeingListed = appDuration == 0 ? true : false;
        require(!isBeingListed || listLength + 1 <= maxListLength, "Exceeds max length"); 
        require(!isBeingListed || IERC20(tokenAddress).transferFrom(msg.sender, address(this), _amount), "Tokens failed to transfer.");

        _add(_recordHash, _amount, _data, msg.sender, isBeingListed, false);
    }


    function proposeWithSig(bytes32 _recordHash, uint _amount, string memory _data, bytes memory _signature) 
        public 
        validateHash(_recordHash, _data) 
        crateIsNotSealed()
        verifyMinDeposit(_amount)
        doesNotExist(_recordHash)
        sufficientBalance(_amount, msg.sender) 
    {
        bytes32 message = keccak256(abi.encode(_recordHash, _data));
        require(Oracle.verify(message, _signature, verifierAddress), "Invalid oracle signature"); // verify signature 

        bool isBeingListed = appDuration == 0 ? true : false;
        require(!isBeingListed || listLength + 1 <= maxListLength, "Exceeds max length"); 
        require(!isBeingListed || IERC20(tokenAddress).transferFrom(msg.sender, address(this), _amount), "Tokens failed to transfer.");

        _add(_recordHash, _amount, _data, msg.sender, isBeingListed, false);
    }

    function privatePropose(bytes32 _secretHash, uint _amount, string memory _secretData,  bytes memory _signature) 
        public
        validateHash(_secretHash, _secretData) 
        crateIsNotSealed()
        verifyMinDeposit(_amount)
        doesNotExist(_secretHash)
        sufficientBalance(_amount, msg.sender) 
    {
        require(verifierAddress != address(0), "Crate owner has not set a verifier address");

        bytes32 message = keccak256(abi.encode(_secretHash, _secretData));
        require(Oracle.verify(message, _signature, verifierAddress), "Invalid oracle signature"); // verify signature 

        bool isBeingListed = appDuration == 0 ? true : false;
        require(!isBeingListed || listLength + 1 <= maxListLength, "Exceeds max length"); 
        require(!isBeingListed || IERC20(tokenAddress).transferFrom(msg.sender, address(this), _amount), "Tokens failed to transfer.");

        records[_secretHash].isPrivate = true;
        records[_secretHash].oracleAddress = verifierAddress;

        _add(_secretHash, _amount, _secretData, msg.sender, isBeingListed, true);
    }

    function revealProposal(bytes32 _secretHash, bytes32 _recordHash, string memory _data, bytes memory _signature) 
        public
        crateIsNotSealed()
        doesExist(_secretHash)
        doesNotExist(_recordHash)
        validateHash(_recordHash, _data)
        isRecordOwner(_secretHash, msg.sender)
        unchallenged(_secretHash)
    {   
        Record memory record = records[_secretHash];
        require(record.isPrivate ,"Listing is not private");

        bytes32 message = keccak256(abi.encode(_secretHash, _secretHash, _signature));
        require(Oracle.verify(message, _signature, record.oracleAddress), "Invalid oracle signature"); // verify signature 

        _remove(_secretHash);

        _add(_recordHash, record.deposit, _data, record.owner, true, false);
    }

    /*
     * @dev Challenge a record or application
     * @notice Triggers a new poll for token holders to settle dispute
     * @param _recordHash keccak256 hash of record identifier
     * @param _amount the amount of tokens to stake for this record (must be at least the staked amount for record)
     */
    function challenge(bytes32 _recordHash, uint _amount, address _payoutAddress) 
        external
        crateIsNotSealed()
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
     * @notice If list length has been reached, winning address can still call this but adding entry to list with be skipped
     * @param _recordHash keccak256 hash of record identifier
     */
    function resolveChallenge(bytes32 _recordHash) public doesExist(_recordHash) {
        Record storage record = records[_recordHash];
        require(record.challengeId > 0 && record.resolved == false, "Has no open challenge");
        require(PollRegistry(pollRegistryAddress).hasResolved(record.challengeId) == true, "Poll has not ended");

        bool challengeFailed = PollRegistry(pollRegistryAddress).hasPassed(record.challengeId);
        address winningOwner = challengeFailed ? record.owner : record.challenger;
        bool shouldBeAdded = challengeFailed && !record.listed;
        bool listHasSpace = listLength + 1 <= maxListLength;
        require(!shouldBeAdded || (shouldBeAdded && (listHasSpace || msg.sender == winningOwner)), "Max length reached or not authorized to skip list addition");
 
        address winner = challengeFailed ? record.owner : record.challengerPayoutAddress;
        uint rewards = challengeFailed ? record.challengeDeposit : record.deposit;

        record.resolved = true;

        require(IERC20(record.tokenAddress).transfer(winner, rewards), "Token transfer failed");

        if (challengeFailed) { 
            emit ChallengeFailed(_recordHash, record.challengeId, rewards, winner);

            if (!record.listed && listHasSpace) {
                uint expiry = listDuration > 0 ? block.timestamp + listDuration : 0;
                emit RecordAdded(_recordHash, record.deposit, record.data, record.owner, expiry, record.isPrivate);
                listLength += 1;
                record.listed = true;
            }
            if (!record.listed && !listHasSpace) {
                 _remove(_recordHash);
            }
        } else { 
            emit ChallengeSucceeded(_recordHash);
            _remove(_recordHash);
        }
    }

    /*
     * @dev Allowlist an application if application time has expired
     * @notice record applicationExpiry should not be zero
     * @param _recordHash keccak256 hash of record identifier
     */
    function resolveApplication(bytes32 _recordHash) public doesExist(_recordHash) {
        Record storage record = records[_recordHash];
        require(!record.listed, "Record already allow listed");
        require(record.challengeId == 0, "Challenge will resolve listing");
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
    function removeRecord(bytes32 _recordHash) public doesExist(_recordHash) {
        Record memory record = records[_recordHash];
        require(record.challengeId == 0 || (record.challengeId > 0 && record.resolved == true), "Record is in challenged state");
        require(record.owner == msg.sender || (record.listingExpiry > 0 && block.timestamp > record.listingExpiry ), "Record can only be removed by owner, challenge or if expired");
        
        require(IERC20(record.tokenAddress).transferFrom(address(this), record.owner, record.deposit), "Tokens failed to transfer.");

        _remove(_recordHash);
    }

    /*
     *
     * BATCH
     *
     */
    function batchPropose(bytes32[] memory _recordHashes, string[] memory _datas, uint _amount) public {
        require(!isSealed, "This crate has been closed");
        uint length = _recordHashes.length;
        require(length > 0, "Hash list must have at least one entry");
        require(length < BATCH_MAX, "Hash list is too long");
        require(_datas.length == length, "Hash list and data list must be of equal length");
        require(IERC20(tokenAddress).balanceOf(msg.sender) >= (_amount * length), "Insufficient token balance");
        require(_amount >= minDeposit, "Not enough stake for application.");

        bool listed = appDuration == 0 ? true : false;
        if (listed) {   
            require(listLength + length <= maxListLength, "Exceeds max length"); 
            listLength += length;
        }

        uint8 addedCount = 0;
        address _tokenAddress = tokenAddress;

        for (uint8 i=0; i < length;) {
            bytes32 _hash = _recordHashes[i];
            string memory _data = _datas[i];
            if (!records[_hash].doesExist) {
                addedCount += 1;

                Record storage record = records[_hash];
                record.listed = listed;
                record.owner = msg.sender;
                record.deposit = _amount;
                record.data = _data;
                record.doesExist = true;
                record.tokenAddress = _tokenAddress;

                if (listed) {
                    uint expiry = listDuration > 0 ? block.timestamp + listDuration : 0;
                    emit RecordAdded(_hash, _amount, _data, msg.sender, expiry, false);
                } else {
                    record.applicationExpiry = block.timestamp + appDuration;

                    emit Application(_hash, _amount, _data, msg.sender, record.applicationExpiry, record.isPrivate);
                }
            }

            unchecked {
                i++;
            }
        }

        if (addedCount > 0) {
            require(IERC20(tokenAddress).transferFrom(msg.sender, address(this), (_amount * addedCount)), "Tokens failed to transfer.");
        }
     }
    

    /*
     * @dev Remove an owned or expired record
     * @param _recordHashes list of keccak256 hashed record identifiers
     */
    function batchRemove(bytes32[] memory _recordHashes) public {
        uint length = _recordHashes.length;
        require(length > 0, "Hash list must have at least one entry");
        require(length < BATCH_MAX,  "Hash list is too long");

        for (uint8 i=0; i < length;) {     
            bytes32 _hash = _recordHashes[i];
            Record storage record = records[_hash];

            if (
                record.listed && // record is in crate
                (record.challengeId == 0 || (record.challengeId > 0 && record.resolved == true)) && // no challenge or challenge has been resolved
                (record.owner == msg.sender || (record.listingExpiry > 0 && block.timestamp > record.listingExpiry)) // caller is owner or list time has expired
            ) {
                require(IERC20(record.tokenAddress).transferFrom(address(this),record.owner, record.deposit), "Tokens failed to transfer.");
                _remove(_hash);
            }

            unchecked {
                i++;
            }                
        }      
    }

    /*
     * @dev Batch allow list applications if application time has expired
     * @notice will skip (not revert) if invalid 
     * @param _recordHashes array of keccak256 hashed record identifiers
     */
    function batchResolveApplication(bytes32[] memory _recordHashes) public {  
        uint length = _recordHashes.length;      
        require(listLength + length <= maxListLength, "Exceeds max length"); 
        uint currentTime = block.timestamp; 

        for (uint8 i=0; i < length;) {   
            bytes32 _hash = _recordHashes[i];

                if (
                records[_hash].doesExist &&
                !records[_hash].listed && 
                records[_hash].challengeId == 0 && 
                records[_hash].applicationExpiry > 0 && 
                currentTime > records[_hash].applicationExpiry
            ) {
                records[_hash].listed = true;
                uint expiry = listDuration > 0 ? block.timestamp + listDuration : 0;

                emit RecordAdded(_hash, records[_hash].deposit, records[_hash].data, records[_hash].owner, expiry, records[_hash].isPrivate);
            }
            
            unchecked {
                i++;
            } 
        } 
    }

    /*
     *
     * ADMIN
     *
     */ 

    function updateRecordViewer(bytes32 _recordHash, address _viewerAddress, bool _canView) 
        public 
        isRecordOwner(_recordHash, msg.sender)
    {
        require(records[_recordHash].isPrivate, "Record is not private");
        privateViewers[_recordHash][_viewerAddress] = _canView;
    } 
    
    function updateDescription(string memory _description) public onlyOwner {
        description = _description;
    }

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

    function updateSortability(bool _sortable) public onlyOwner {
        isSortable = _sortable;
    }

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
     * @notice if set to zero, record will get listed instantly
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

    function isRecordListed(bytes32 _recordHash) public view returns (bool listed, address owner) {
        return (records[_recordHash].listed, records[_recordHash].owner);
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

    function getRecord(bytes32 _recordHash) public view returns (Record memory record) {
        return records[_recordHash];
    }

    /*
     *
     * PRIVATE
     *
     */

     function _add(bytes32 _hash,uint _amount, string memory _data, address _sender, bool isBeingListed, bool isPrivate) private {
        Record storage record = records[_hash];
        record.owner = _sender;
        record.deposit = _amount;
        record.data = _data;
        record.doesExist = true;
        record.tokenAddress = tokenAddress;
        

        if (isBeingListed) {
            uint listingExpiry = listDuration > 0 ? block.timestamp + listDuration : 0;
            record.listed = true;
            listLength += 1;
            record.listingExpiry = listingExpiry;
            emit RecordAdded(_hash, _amount, _data, _sender, listingExpiry, isPrivate);
        } else {
            record.applicationExpiry = block.timestamp + appDuration;
            emit Application(_hash, _amount, _data, _sender, record.applicationExpiry, isPrivate);
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
