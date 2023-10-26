// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import {PollRegistry} from "./PollRegistry.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";


contract Crate is Ownable { 

    string public name;
    uint public deposit;
    uint public appDuration;
    uint public listDuration;
    address public crateAdmin;
    ERC20 public token;
    PollRegistry public pollRegistry;
    uint8 public constant BATCH_MAX = 51; 
    
    /*
     *
     * STRUCTS
     *
     */
    struct Record {
        uint applicationExpiry; // Expiration date of apply stage
        bool allowListed;       // Indicates registry status
        address owner;          // Owner of Listing
        uint challengeId;       // the challenge id of the current challenge
        uint deposit;           // Number of tokens locked in listing
        string data;            // id or ipfs hash. 
        address challenger;     // challenger address
        uint challengeDeposit;  // challenge deposit amount
        bool resolved;          // true if listing has been challenged and voting has closed
        uint listingExpiry;     // zero if no expiration, otherwise listing expire time
        bool exists;
    }
    
    /*
     *
     * Mappings
     *
     */
    mapping(bytes32 => Record) public records; // This mapping holds the listings for this crate

    /*
     *
     * EVENTS
     *
     */ 
    event _Application(bytes32 indexed listingHash, uint deposit, string data, address indexed applicant);
    event _ApplicationAllowlisted(bytes32 indexed listingHash);
    event _Challenge(bytes32 indexed listingHash, uint challengeId, address indexed challenger);
    event _ChallengeFailed(bytes32 indexed listingHash, uint indexed challengeID, uint rewardPool, uint totalTokens);
    event _ChallengeSucceededListingRemoved(bytes32 indexed listingHash);
    event _ApplicationRemoved(bytes32 indexed listingHash);
    event _ListingRemoved(bytes32 indexed listingHash);


    constructor (string memory _name, address _token, address _voting, uint _deposit) {
        require(_token != address(0), "Token address should not be zero address");
        token = ERC20(_token);
        pollRegistry = PollRegistry(_voting);
        name = _name;
        deposit = _deposit;
        appDuration = 0; // no application period
        listDuration = 0; // no listing period
    }

    /*
     *
     * CORE
     *
     */ 

    /*
     * @dev Propose a listing to add to crate
     * @notice If no app duration set, listing will be automatically allow listed
     * @param _listingHash keccak256 hash of record identifier
     * @param _amount the amount of tokens to stake for this listing (must be at least deposit)
     * @param _data metadata string or uri 
     */
    function propose(bytes32 _listingHash, uint _amount, string memory _data) public {
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        require(!isAllowlisted(_listingHash), "Listing is already on allow list.");
        require(!appWasMade(_listingHash), "Listing is already in apply stage.");
        require(_amount >= deposit, "Not enough stake for application.");

        bool allowListed = appDuration == 0 ? true : false;

        Record storage record = records[_listingHash];
        record.allowListed = allowListed;
        record.owner = msg.sender;
        record.deposit = _amount;
        record.data = _data;
        record.exists = true;

        if (appDuration > 0) record.applicationExpiry = block.timestamp + appDuration;

        require(token.transferFrom(msg.sender, address(this), _amount), "Tokens failed to transfer.");

        if (allowListed) {
            emit _ApplicationAllowlisted(_listingHash);
        } else {
            emit _Application(_listingHash, _amount, _data, msg.sender);
        }
    }

    /*
     * @dev Challenge a listing or application
     * @notice Triggers a new poll for token holders to settle dispute
     * @param _listingHash keccak256 hash of record identifier
     * @param _amount the amount of tokens to stake for this listing (must be at least the staked amount for listing)
     */
    function challenge(bytes32 _listingHash, uint _amount) external returns (uint challengeID) {
        Record storage record = records[_listingHash];
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");
        require(_amount >= record.deposit, "Not enough stake for application.");
        require(appWasMade(_listingHash) || record.allowListed, "Listing does not exist.");
        require(record.challengeId == 0, "Listing has already been challenged.");

        uint newPollId = pollRegistry.createPoll(address(token));
        record.challengeId = newPollId;
        record.challenger = msg.sender;
        record.challengeDeposit += _amount;

        require(token.transferFrom(msg.sender, address(this), _amount), "Tokens failed to transfer.");

        emit _Challenge(_listingHash, newPollId, msg.sender);

        return newPollId;
    }

    /*
     * @dev Allow list an application if application time has expired
     * @notice record applicationExpiry should not be zero
     * @param _listingHash keccak256 hash of record identifier
     */
    function resolveListing(bytes32 _listingHash) public {
        Record memory record = records[_listingHash];
        require(abi.encode(record).length > 0, "Record does not exist");
        require(record.challengeId == 0, "Challenge will resolve listing");
        require(record.applicationExpiry > 0 && block.timestamp > record.applicationExpiry, "Record has no Expiry or has not expired");
        
        records[_listingHash].allowListed = true;
        emit _ApplicationAllowlisted(_listingHash);
    }

    /*
     * @dev Remove an owned or expired record
     * @param _listingHash keccak256 hash of record identifier
     */
    function removeListing(bytes32 _listingHash) public {
        Record memory record = records[_listingHash];
        require(abi.encode(record).length > 0, "Record does not exist");
        require(record.challengeId == 0 || (record.challengeId > 0 && record.resolved == true), "Listing is in challenged state");
        require(record.owner == msg.sender || (record.listingExpiry > 0 && block.timestamp > record.listingExpiry ), "Only listing owner or successful challenge can remove listing");
        
        delete records[_listingHash];
        emit _ListingRemoved(_listingHash);
    }

    /*
     * @dev Resolve challenge once voting has completed
     * @param _listingHash keccak256 hash of record identifier
     * @param _amount the amount of tokens to stake for this listing (must be at least the staked amount for listing)
     */
    function resolveChallenge(bytes32 _listingHash) public {
        Record storage record = records[_listingHash];
        require(record.challengeId > 0, "No challenge for listing");
        require(record.resolved == false, "Challenge has already been resolved");
        require(pollRegistry.hasResolved(record.challengeId) == true, "Poll has not ended");


        address recordOwner = record.owner;
        uint ownerDeposit = record.deposit;
        uint challengeId = record.challengeId;
        uint challengeDeposit = record.challengeDeposit;
        uint rewards = ownerDeposit + challengeDeposit;

        record.resolved = true;

        address winner;

        if (pollRegistry.hasPassed(challengeId)) { //challenge failed
            emit _ApplicationAllowlisted(_listingHash);
            record.allowListed = true;
            winner = recordOwner;
        } else { // challenge succeeded
            winner = record.challenger;
            if(record.allowListed){ 
                emit _ListingRemoved(_listingHash);
            } else {
                emit _ApplicationRemoved(_listingHash);
            }

            delete records[_listingHash];
        }

        require(token.transfer(winner, rewards));
    }

    /*
     *
     * BATCH
     *
     */
    function batchPropose(bytes32[] memory _listingHashes, string[] memory _datas, uint _amount) public {
        uint length = _listingHashes.length;
        require(length > 0, "Hash list must have at least one entry");
        require(length < BATCH_MAX, "Hash list is too long");
        require(_datas.length == length, "Hash list and data list must be of equal length");
        require(token.balanceOf(msg.sender) >= (_amount * length), "Insufficient token balance");
        require(_amount >= deposit, "Not enough stake for application.");

        uint8 addedCount = 0;
        bool allowListed = appDuration == 0 ? true : false;
        uint expiry = block.timestamp + appDuration;

        unchecked {
            for (uint8 i=0; i < length;) {
                bytes32 _hash = _listingHashes[i];
                string memory _data = _datas[i];
                if (!isAllowlisted(_hash) && !appWasMade(_hash)) {
                    addedCount += 1;

                    Record storage record = records[_hash];
                    record.allowListed = allowListed;
                    record.owner = msg.sender;
                    record.deposit = _amount;
                    record.data = _data;
                    record.applicationExpiry = expiry;

                    if (allowListed) {
                        emit _ApplicationAllowlisted(_hash);
                    } else {
                        emit _Application(_hash, _amount, _data, msg.sender);
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
     * @param _listingHash keccak256 hash of record identifier
     */
    function batchRemove(bytes32[] memory _listingHashes) public {
        uint length = _listingHashes.length;
        require(length > 0, "Hash list must have at least one entry");
        require(length < BATCH_MAX,  "Hash list is too ");

        uint refundAmount = 0;
        unchecked {
            for (uint8 i=0; i < length;) {     
                bytes32 _hash = _listingHashes[i];
                Record storage record = records[_hash];

                if (
                    record.allowListed == true && // record is in crate
                    (record.challengeId == 0 || (record.challengeId > 0 && record.resolved == true)) && // no challenge or challenge has been resolved
                    (record.owner == msg.sender || (record.listingExpiry > 0 && block.timestamp > record.listingExpiry)) // caller is owner or list time has expired
                ) {
                    refundAmount += record.deposit;          
                    delete records[_hash];
                    emit _ListingRemoved(_hash);
                }
            }
        }

        if (refundAmount > 0) {
            token.transferFrom(address(this), msg.sender, refundAmount);
        }         
    }

    function encode(bytes32 _hash) public {
        bool res =  challengeResolved(_hash);
    }

    /*
     *
     * ADMIN
     *
     */ 
    
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
     * @notice if set to zero, record will get allowlisted instantly
     * @param _duration number of seconds until an unchallenged application can be allowlisted
     */
    function updateAppDuration(uint _duration) public onlyOwner {
         appDuration = _duration;
    }

    /*
     * @dev Updates listing duration 
     * @notice if set to zero, listing will never expire and can only be removed by owner or poll
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
    function isAllowlisted(bytes32 _listingHash) view internal returns (bool allowListed) {
        return records[_listingHash].allowListed;
    }

    function appWasMade(bytes32 _listingHash) view internal returns (bool exists) {
        return records[_listingHash].applicationExpiry > 0;
    }

    function challengeResolved(bytes32 _listingHash) view public returns (bool exists) {
        return records[_listingHash].challengeId > 0 && records[_listingHash].resolved == true;
    }

    function getRecord(bytes32 _listingHash) view public returns (Record memory) {
        return records[_listingHash];
    }

    function setAdmin(address _adminAddress) public onlyOwner {
        crateAdmin = _adminAddress;
    }
}