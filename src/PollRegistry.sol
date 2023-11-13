// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/token/ERC20/ERC20.sol";
import "openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";
import "./Reward.sol";

/*
 * @title Poll Registry
 * @description A polling hyperstructure to allow token holders to vote and settle disputes 
 */

contract PollRegistry is ReentrancyGuard {
    uint private pollId;

    /*
     *
     * CONSTANTS
     *
     */
    uint public constant VOTE_QUORUM = 50; // major wins
    uint public constant COMMIT_DURATION = 86400; // one day 
    uint public constant REVEAL_DURATION = 86400; // one day 

    /*
     *
     * STRUCTS
     *
     */
    struct Poll {
        bool exists;
        uint commitEndDate;     /// expiration date of commit period for poll
        uint revealEndDate;     /// expiration date of reveal period for poll
        uint voteQuorum;	    /// number of votes required for a proposal to pass
        uint votesFor;		    /// tally of votes supporting proposal
        uint votersFor;
        uint votesAgainst;      /// tally of votes countering proposal
        uint votersAgainst;
        address tokenAddress;   /// token address for poll
        bool passed;            // did poll pass
        bool resolved;          // has poll been resolved
        uint totalDeposits;     // total number of staked tokens for this poll
        uint rewardPool;        // total number of tokens to be distributed to winning voters
        uint winnerWithdrawalCount;  // total number of withdrawals for winners 
        address winnerAddress;
        uint withdrawnRewardAmount;
        address proposerAddress;
        address challengerAddress;
        
    }

    /*
     *
     * MAPPINGS
     *
     */
    mapping(uint => mapping(address => bool)) public commits;  // pollId > wallet address > did commit a vote
    mapping(uint => mapping(address => bool)) public reveals;  // pollId > wallet address > did reveal a vote
    mapping(uint => Poll) private polls;                        // pollId > Poll
    mapping(uint => mapping(address => uint)) public balances; // pollId > wallet address > balance
    mapping(uint => mapping(address => bool)) public votes;    // pollId > voter address > vote (for or against)
    mapping(uint => mapping(address => bytes32)) public voteHashes; // pollId > voter address > hashed vote (pre reveal)

    /*
     *
     * EVENTS
     *
     */
    event PollCreated(uint commitEndDate, uint revealEndDate, uint indexed pollId, address indexed creator);
    event VoteCommitted(uint pollId, uint _amount, address voter);
    event VoteRevealed(uint indexed pollId, uint numTokens, bool indexed choice, address indexed voter);

    /*
     *
     * MODIFIERS
     *
     */
    modifier pollExists(uint _pollId) {
        require(abi.encode(polls[_pollId]).length > 0, "Poll does not exist");
        _; 
    }

    modifier pollEnded(uint _pollId) {
        require(block.timestamp > polls[_pollId].revealEndDate, "Poll hasn't ended");
        _;
    }

    /*
     *
     * CONSTRUCTOR
     *
     */
    constructor() {
        pollId += 1; // start poll id at 1
    }

    /*
     *
     * CORE FUNCTIONS
     *
     */

     /*
      * @dev Initializes a new poll instance
      * @param _tokenAddress address of token needed to stake and place vote
      */
    function createPoll(address _tokenAddress, address _proposerAddress, address _challengerAddress) public returns (uint newPollId) {
        newPollId = pollId;
        pollId += 1;

        uint commitEndDate = block.timestamp + COMMIT_DURATION;
        uint revealEndDate = commitEndDate + REVEAL_DURATION;

        Poll storage poll = polls[newPollId];
        poll.exists = true;
        poll.voteQuorum = VOTE_QUORUM;
        poll.tokenAddress = _tokenAddress;
        poll.commitEndDate = commitEndDate;
        poll.revealEndDate = revealEndDate;

        emit PollCreated(commitEndDate, revealEndDate, newPollId, msg.sender);

        return newPollId;
    }

    /*
     * @dev Commit a vote for or against 
     * @notice Voting is a two step process (commit & reveal) to avoid voter's siding with the front runner
     * @notice Voting is token weighted. _amount is equivalent to number of votes for this user.
     * @notice If user commits and does not reveal, they forfeit their staked tokens.
     * @param _pollId id of poll to vote on
     * @param _secretHash keccak256 hash of user's vote + random salt
     * @param _amount amount of tokens to stake on this vote. 1 token = 1 vote
     */
    function commitVote(uint _pollId, bytes32 _secretHash, uint _amount) public pollExists(_pollId) nonReentrant {
        Poll memory poll = polls[_pollId];
        require(poll.exists == true, "Poll does not exist");
        require(block.timestamp < poll.commitEndDate, "Commit stage not active");
        require(!commits[_pollId][msg.sender], "Already committed a vote");
        require(_secretHash != bytes32(0), "Secret hash cannot be empty");

        ERC20 token = ERC20(poll.tokenAddress);
        require(token.balanceOf(msg.sender) >= _amount, "Insufficient token balance");

        balances[_pollId][msg.sender] = _amount;
        require(token.transferFrom(msg.sender, address(this), _amount), "Token transfer failed");

        commits[_pollId][msg.sender] = true;
        voteHashes[_pollId][msg.sender] = _secretHash;

        poll.totalDeposits += _amount;

        emit VoteCommitted(_pollId, _amount, msg.sender);
    }

    /*
     * @dev Reveal caller's submitted vote
     * @param _pollId id of poll to vote on
     * @param _salt random number defined by caller to commitVote
     * @param _vote the vote committed to commitVote, either for or against
     */
    function revealVote(uint _pollId, uint _salt, bool _vote) public pollExists(_pollId){
        Poll memory poll = polls[_pollId];
        require(poll.commitEndDate < block.timestamp && block.timestamp < poll.revealEndDate, "Reveal stage not active");
        require(commits[_pollId][msg.sender], "No vote committed");
        require(!reveals[_pollId][msg.sender], "Already revealed a vote");
        require(keccak256(abi.encodePacked(_vote, _salt)) == voteHashes[_pollId][msg.sender]);

        uint _amount = balances[_pollId][msg.sender];

        if(_vote) {
            poll.votesFor += _amount;
            polls[_pollId].votersFor += 1;
        } else {
            poll.votesAgainst += _amount;
            polls[_pollId].votersAgainst += 1;
        }

        reveals[_pollId][msg.sender] = true;
        votes[_pollId][msg.sender] = _vote;
 
        emit VoteRevealed(_pollId, _amount, _vote, msg.sender);
    }

    /*
     * @dev Close poll and calculate reward pool
     * @param _pollId id of poll to resolve
     */
    function resolvePoll(uint _pollId) public view {
        Poll memory poll = polls[_pollId];
        require(block.timestamp > poll.revealEndDate, "Poll has not ended");

        bool passed = hasPassed(_pollId);
        uint winnerPool = passed ? poll.votesFor : poll.votesAgainst;

        poll.winnerAddress = passed ? poll.proposerAddress : poll.challengerAddress;
        poll.rewardPool = poll.totalDeposits - winnerPool;
        poll.resolved = true;        
        poll.passed = passed;
    }

    /*
     * @dev Withdraw user balance once poll has completed
     * @param _pollId id of poll to withdraw balance from
     */
    function withdrawBalance(uint _pollId) public nonReentrant {
        Poll memory poll = polls[_pollId];

        require(poll.resolved == true, "Poll has not ended");
        require(reveals[_pollId][msg.sender] == true, "User did not reveal vote");
        require(votes[_pollId][msg.sender] == poll.passed, "User did not vote for winner party");
        require(balances[_pollId][msg.sender] > 0, "User has no balance to withdraw");

        uint amountToSend = balances[_pollId][msg.sender];

        balances[_pollId][msg.sender] = 0;

        uint stakedTotal = poll.passed ? poll.votesFor : poll.votesAgainst;

        uint voterTotal = poll.passed ? poll.votersFor : poll.votersAgainst;

        poll.winnerWithdrawalCount += 1;

        uint reward = Reward.rewardPoolShare(poll.rewardPool, amountToSend, stakedTotal);

        poll.withdrawnRewardAmount += reward;

        ERC20(polls[_pollId].tokenAddress).transferFrom(address(this), msg.sender, amountToSend + reward);

        uint remnants = poll.rewardPool - poll.withdrawnRewardAmount;

        // if everyone has withdrawn, send remnants to poll winner  
        if (voterTotal == poll.winnerWithdrawalCount && remnants > 0) {
            ERC20(polls[_pollId].tokenAddress).transferFrom(address(this), poll.winnerAddress, remnants);
        } 
    }



    /*
     *
     * HELPER FUNCTIONS
     *
     */
    function hasPassed(uint _pollId) public view pollExists(_pollId) pollEnded(_pollId) returns (bool) {
        Poll memory poll = polls[_pollId];
        return (100 * poll.votesFor) > (poll.voteQuorum * (poll.votesFor + poll.votesAgainst));
    }

    function getPoll(uint _pollId) external view returns (Poll memory) {
        return polls[_pollId];
    }

    function hasResolved(uint _pollId) external view returns (bool) {
        return polls[_pollId].resolved;
    }

}
