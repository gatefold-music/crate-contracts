// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {PollRegistry} from "./PollRegistry.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


contract Crate is Ownable { 
    string public name;
    uint public minDeposit;
    uint public appDuration;
    uint public listDuration;
    address public crateAdmin;
    ERC20 public token;
    PollRegistry public pollRegistry;
    uint8 public constant BATCH_MAX = 51; 
    bool public closed;
    
    /*
     *
     * STRUCTS
     *
     */
    struct Record {
        uint applicationExpiry; // Expiration date of apply stage
        bool listed;       // Indicates registry status
        address owner;          // Owner of recrod
        uint challengeId;       // the challenge id of the current challenge
        uint deposit;           // Number of tokens staked for this record
        string data;            // id or ipfs hash. 
        address challenger;     // challenger address
        uint challengeDeposit;  // challenge deposit amount
        address challengerPayoutAddress; // address to send payout or refund (if empty address, defaults to challenger address)
        bool resolved;          // true if record has been challenged and voting has closed
        uint listingExpiry;     // zero if no expiration, otherwise record expire time
        bool exists;            // for validating if a record exists;
        address tokenAddress;    // token address for this record 
    }
    
    /*
     *
     * Mappings
     *
     */
    mapping(bytes32 => Record) public records; // This mapping holds the listings for this list

    /*
     *
     * EVENTS
     *
     */ 
    event Application(bytes32 indexed recordHash, uint deposit, string data, address indexed applicant);
    event RecordAdded(bytes32 indexed recordHash);
    event Challenge(bytes32 indexed recordHash, uint challengeId, address indexed challenger);
    event ChallengeFailed(bytes32 indexed recordHash, uint indexed challengeId, uint rewardPool, address winner);
    event ChallengeSucceeded(bytes32 indexed recordHash);
    event ApplicationRemoved(bytes32 indexed recordHash);
    event RecordRemoved(bytes32 indexed recordHash);


    constructor (string memory _name, address _token, address _voting, uint _minDeposit) {
        require(_token != address(0), "Token address should not be zero address");
        token = ERC20(_token);
        pollRegistry = PollRegistry(_voting);
        name = _name;
        minDeposit = _minDeposit;
        appDuration = 0; // no application period
        listDuration = 0; // no listing period
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
    function propose(bytes32 _recordHash, uint _amount, string memory _data) public {
        require(!closed, "This crate has been closed");
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        require(!records[_recordHash].exists, "Record already exists");
        // require(!isAllowlisted(_recordHash), "Record is already listed");
        // require(!appWasMade(_recordHash), "Record is already in apply stage.");
        require(_amount >= minDeposit, "Not enough stake for application.");

        bool listed = appDuration == 0 ? true : false;

        Record storage record = records[_recordHash];
        record.listed = listed;
        record.owner = msg.sender;
        record.deposit = _amount;
        record.data = _data;
        record.exists = true;
        record.tokenAddress = address(token);

        if (appDuration > 0) record.applicationExpiry = block.timestamp + appDuration;

        require(token.transferFrom(msg.sender, address(this), _amount), "Tokens failed to transfer.");

        if (listed) {
            emit RecordAdded(_recordHash);
        } else {
            emit Application(_recordHash, _amount, _data, msg.sender);
        }
    }

    /*
     * @dev Challenge a record or application
     * @notice Triggers a new poll for token holders to settle dispute
     * @param _recordHash keccak256 hash of record identifier
     * @param _amount the amount of tokens to stake for this record (must be at least the staked amount for record)
     */
    function challenge(bytes32 _recordHash, uint _amount, address payoutAddress) external returns (uint challengeID) {
        require(!closed, "This crate has been closed");
        Record storage record = records[_recordHash];
        require(ERC20(record.tokenAddress).balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        require(_amount >= record.deposit, "Not enough stake for application.");
        require(record.exists, "Record does not exist."); 
        require(record.challengeId == 0, "Record has already been challenged.");

        uint newPollId = pollRegistry.createPoll(record.tokenAddress);
        record.challengeId = newPollId;
        record.challenger = msg.sender;
        record.challengerPayoutAddress = payoutAddress != address(0) ? payoutAddress : msg.sender;
        record.challengeDeposit += _amount;

        require(ERC20(record.tokenAddress).transferFrom(msg.sender, address(this), _amount), "Tokens failed to transfer.");

        emit Challenge(_recordHash, newPollId, msg.sender);

        return newPollId;
    }

    /*
     * @dev Allowlist an application if application time has expired
     * @notice record applicationExpiry should not be zero
     * @param _recordHash keccak256 hash of record identifier
     */
    function resolveApplication(bytes32 _recordHash) public {
        Record memory record = records[_recordHash];
        require(abi.encode(record).length > 0, "Record does not exist");
        require(!record.listed, "Record already allow listed");
        require(record.challengeId == 0, "Challenge will resolve listing");
        require(record.applicationExpiry > 0 && block.timestamp > record.applicationExpiry, "Record has no Expiry or has not expired");
        
        records[_recordHash].listed = true;
        emit RecordAdded(_recordHash);
    }

    /*
     * @dev Remove an owned or expired record
     * @param _recordHash keccak256 hash of record identifier
     */
    function removeRecord(bytes32 _recordHash) public {
        Record memory record = records[_recordHash];
        require(abi.encode(record).length > 0, "Record does not exist");
        require(record.challengeId == 0 || (record.challengeId > 0 && record.resolved == true), "Record is in challenged state");
        require(record.owner == msg.sender || (record.listingExpiry > 0 && block.timestamp > record.listingExpiry ), "Only record owner or successful challenge can remove record from list");
        
        require(ERC20(record.tokenAddress).transferFrom(address(this),record.owner, record.deposit), "Tokens failed to transfer.");

        delete records[_recordHash];
        emit RecordRemoved(_recordHash);
    }

    /*
     * @dev Resolve challenge once voting has completed
     * @param _recordHash keccak256 hash of record identifier
     */
    function resolveChallenge(bytes32 _recordHash) public {
        Record storage record = records[_recordHash];
        require(record.challengeId > 0, "No challenge for record");
        require(record.resolved == false, "Challenge has already been resolved");
        require(pollRegistry.hasResolved(record.challengeId) == true, "Poll has not ended");


        address recordOwner = record.owner;
        uint challengeId = record.challengeId;
        uint challengeDeposit = record.challengeDeposit;
        uint rewards = 0;

        record.resolved = true;

        address winner;

        if (pollRegistry.hasPassed(challengeId)) { //challenge failed 
            winner = recordOwner;
            rewards = challengeDeposit;
            emit ChallengeFailed(_recordHash, challengeId, rewards, winner);

            if (!record.listed) {
                emit RecordAdded(_recordHash);
                record.listed = true;
            }
        } else { // challenge succeeded
            emit ChallengeSucceeded(_recordHash);
            winner = record.challengerPayoutAddress;
            rewards = record.deposit;
            if(record.listed){ 
                emit RecordRemoved(_recordHash);
            } else {
                emit ApplicationRemoved(_recordHash);
            }

            delete records[_recordHash];
        }

        require(ERC20(record.tokenAddress).transfer(winner, rewards));
    }

    /*
     *
     * BATCH
     *
     */
    function batchPropose(bytes32[] memory _recordHashes, string[] memory _datas, uint _amount) public {
        require(!closed, "This crate has been closed");
        uint length = _recordHashes.length;
        require(length > 0, "Hash list must have at least one entry");
        require(length < BATCH_MAX, "Hash list is too long");
        require(_datas.length == length, "Hash list and data list must be of equal length");
        require(token.balanceOf(msg.sender) >= (_amount * length), "Insufficient token balance");
        require(_amount >= minDeposit, "Not enough stake for application.");

        uint8 addedCount = 0;
        bool listed = appDuration == 0 ? true : false;
        uint expiry = block.timestamp + appDuration;
        address tokenAddress = address(token);

        unchecked {
            for (uint8 i=0; i < length;) {
                bytes32 _hash = _recordHashes[i];
                string memory _data = _datas[i];
                if (!records[_hash].exists) {
                    addedCount += 1;

                    Record storage record = records[_hash];
                    record.listed = listed;
                    record.owner = msg.sender;
                    record.deposit = _amount;
                    record.data = _data;
                    record.applicationExpiry = expiry;
                    record.exists = true;
                    record.tokenAddress = tokenAddress;

                    if (listed) {
                        emit RecordAdded(_hash);
                    } else {
                        emit Application(_hash, _amount, _data, msg.sender);
                    }
                }
                i++;
            }
        }

        if (addedCount > 0) {
            require(token.transferFrom(msg.sender, address(this), (_amount * addedCount)), "Tokens failed to transfer.");
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

        // uint refundAmount = 0;
        unchecked {
            for (uint8 i=0; i < length;) {     
                bytes32 _hash = _recordHashes[i];
                Record storage record = records[_hash];

                if (
                    record.listed && // record is in crate
                    (record.challengeId == 0 || (record.challengeId > 0 && record.resolved == true)) && // no challenge or challenge has been resolved
                    (record.owner == msg.sender || (record.listingExpiry > 0 && block.timestamp > record.listingExpiry)) // caller is owner or list time has expired
                ) {
                    require(ERC20(record.tokenAddress).transferFrom(address(this),record.owner, record.deposit), "Tokens failed to transfer.");
                    delete records[_hash];
                    emit RecordRemoved(_hash);
                }
            }
        }

        // if (refundAmount > 0) {
        //     token.transferFrom(address(this), msg.sender, refundAmount);
        // }         
    }

    /*
     * @dev Batch allow list applications if application time has expired
     * @notice will skip (not revert) if invalid 
     * @param _recordHashes array of keccak256 hashed record identifiers
     */
    function batchResolveApplication(bytes32[] memory _recordHashes) public {  
        uint length = _recordHashes.length;      
        uint currentTime = block.timestamp;

        unchecked {
            for (uint8 i=0; i < length;) {   
                bytes32 _hash = _recordHashes[i];

                 if (
                    records[_hash].exists &&
                    !records[_hash].listed && 
                    records[_hash].challengeId == 0 && 
                    records[_hash].applicationExpiry > 0 && 
                    currentTime > records[_hash].applicationExpiry
                ) {
                    records[_hash].listed = true;
                    emit RecordAdded(_hash);
                }
            } 
        } 
    }

    function encode(bytes32 _hash) public {
        for (uint i = 0; i < 10 ;i++) {
            require(i < 5, "REJECTED");
            emit RecordAdded(_hash);
        }
    }

    /*
     *
     * ADMIN
     *
     */ 
    
    
    /*
     * @dev This locks the crate fooooreeeeeveer
     * @notice any pending challenges (polls) can still be resolved even after locking
     * @notice this action cannot be undone
     * @param _token erc20 token address to use for new proposals 
     */
    function close() public onlyOwner {
        closed = true;
    }
    
    /*
     * @dev Updates the Token 
     * @notice does not account for old token balances
     * @param _token erc20 token address to use for new proposals 
     */
    function updateToken(address _token) public onlyOwner {
        token = ERC20(_token);
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

    /*
     *
     * UTILS
     *
     */ 
    // function isAllowlisted(bytes32 _recordHash) view internal returns (bool allowListed) {
    //     return records[_recordHash].listed;
    // }

    // function appWasMade(bytes32 _recordHash) view internal returns (bool exists) {
    //     return records[_recordHash].applicationExpiry > 0;
    // }

    function challengeResolved(bytes32 _recordHash) view public returns (bool exists) {
        return records[_recordHash].challengeId > 0 && records[_recordHash].resolved == true;
    }

    function getRecord(bytes32 _recordHash) view public returns (Record memory) {
        return records[_recordHash];
    }

    function setAdmin(address _adminAddress) public onlyOwner {
        crateAdmin = _adminAddress;
    }
}