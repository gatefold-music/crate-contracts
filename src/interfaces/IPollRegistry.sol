// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

abstract contract IPollRegistry is ERC165 {
    uint internal pollId;

    event PollCreated(uint commitEndDate, uint revealEndDate, uint indexed pollId, address indexed creator);
    event VoteCommitted(uint pollId, uint _amount, address voter);
    event VoteRevealed(uint indexed pollId, uint numTokens, bool indexed choice, address indexed voter);
    
    function createPoll(address _tokenAddress, address _proposerAddress, address _challengerAddress) public virtual returns (uint newPollId);

    function commitVote(uint _pollId, bytes32 _secretHash, uint _amount) public virtual;

    function revealVote(uint _pollId, uint _salt, bool _vote) public virtual;

    function resolvePoll(uint _pollId) public virtual;

    function withdrawBalance(uint _pollId) public virtual;

    function hasPassed(uint _pollId) public view virtual returns (bool);

    function hasResolved(uint _pollId) external view virtual returns (bool);

    function canResolve(uint _pollId) external view virtual returns (bool);
}