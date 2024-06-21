// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../../src/poll/PollRegistry.sol";
import {CurationToken} from "../../src/token/CurationToken.sol";


contract PollRegistryTest is Test {
    uint public constant VOTE_QUORUM = 50; // majority wins
    uint public constant COMMIT_DURATION = 86400; // one day 
    uint public constant REVEAL_DURATION = 86400; // one day 

    PollRegistry public pr;
    address public owner = address(0x69420);
    address public proposer = address(0x12345);
    address public challenger = address(0x67890);
    address public voter1 = address(0x11111);
    address public voter2 = address(0x22222);
    address public voter3 = address(0x33333);

    event PollCreated(uint commitEndDate, uint revealEndDate, uint indexed pollId, address indexed creator);
    event VoteCommitted(uint pollId, uint _amount, address voter);
    event VoteRevealed(uint indexed pollId, uint numTokens, bool indexed choice, address indexed voter);

    CurationToken public token;
    function setUp() public {
        pr = new PollRegistry();

        vm.prank(owner);
        token = new CurationToken();
        token.initialize("Test Token", "TEST", owner);

         vm.prank(owner);
         token.mint(owner, 1000);

        vm.prank(address(pr));
        token.maxApproval(address(pr));

        vm.prank(owner);
        token.mint(proposer, 100);

        vm.prank(proposer);
        token.approve(address(pr));

        vm.prank(owner);
        token.mint(challenger, 100);

        vm.prank(challenger);
        token.approve(address(pr));

        vm.prank(owner);
        token.mint(voter1, 100);

        vm.prank(voter1);
        token.approve(address(pr));

        vm.prank(owner);
        token.mint(voter2, 100);

        vm.prank(voter2);
        token.approve(address(pr));

        vm.prank(owner);
        token.mint(voter3, 100);

        vm.prank(voter3);
        token.approve(address(pr));
    }

    /*
        Create Poll
     */

    function testCreatePoll() public {
        uint commitEndDate = block.timestamp + COMMIT_DURATION;
        uint revealEndDate = commitEndDate + REVEAL_DURATION;

        vm.expectEmit(true, true, true, true);
        emit PollCreated(commitEndDate, revealEndDate, 1, address(this));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);

        assertEq(pollId, 1);
        assertEq(poll.commitEndDate, block.timestamp + 86400);
        assertEq(poll.revealEndDate, block.timestamp + 86400 + 86400);
        assertEq(poll.exists, true);
        assertEq(poll.voteQuorum, 50);
        assertEq(poll.tokenAddress, address(token));
        assertEq(poll.proposerAddress, proposer);
        assertEq(poll.challengerAddress, challenger);
    }

    /*
        Commit vote
     */

    function testCommitVote() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.expectEmit(true, true, true, true);
        emit VoteCommitted(pollId, 1, voter1);
        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  1);
        
        uint voterBalance = pr.balances(pollId, voter1);
        bool hasCommitted = pr.commits(pollId, voter1);
        bytes32 secretHash =  pr.voteHashes(pollId, voter1);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);

        assertEq(voterBalance, 1);
        assertEq(hasCommitted, true);
        assertEq(secretHash, secretVote);
        assertEq(poll.totalDeposits, 1);
    }

    function test_PollDoesntExist() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));

        vm.prank(voter1);
        vm.expectRevert("Poll does not exist");
        pr.commitVote(1, secretVote,  1);
    }

    function test_CommitStageHasEnded() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);
        vm.prank(voter1);
        vm.expectRevert("Commit stage has ended");
        pr.commitVote(pollId, secretVote,  1);
    }

    function test_NoDuplicateVotes() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  1);

        vm.prank(voter1);
        vm.expectRevert("Already committed a vote");
        pr.commitVote(pollId, secretVote,  1);
    }

    function test_NoEmptyHash() public {
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        vm.expectRevert("Secret hash cannot be empty");
        pr.commitVote(pollId, bytes32(0),  1);
    }

    function test_InsufficientBalance() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        vm.expectRevert("Insufficient token balance");
        pr.commitVote(pollId, secretVote,  101);
    }

    function test_FailedTransfer() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        vm.expectRevert("Insufficient token balance");
        pr.commitVote(pollId, secretVote,  101);
    }

    /*
        Reveal vote
     */

     function testRevealVoteFor() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  1);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.expectEmit(true, true, true, true);
        emit VoteRevealed(pollId, 1, true,  voter1);
        vm.prank(voter1);
        pr.revealVote(pollId, salt,  true);

        assertEq(pr.reveals(pollId, voter1), true);
        assertEq(pr.votes(pollId, voter1), true);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);
        assertEq(poll.votesFor, 1);
        assertEq(poll.votersFor, 1);
     }

    function testRevealVoteAgainst() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(false, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  1);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.expectEmit(true, true, true, true);
        emit VoteRevealed(pollId, 1, false,  voter1);
        vm.prank(voter1);
        pr.revealVote(pollId, salt,  false);

        assertEq(pr.reveals(pollId, voter1), true);
        assertEq(pr.votes(pollId, voter1), false);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);
        assertEq(poll.votesAgainst, 1);
        assertEq(poll.votersAgainst, 1);
     }

    function test_NotInRevealStage() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  1);


        vm.expectRevert("Reveal stage not active");
        vm.prank(voter1);
        pr.revealVote(pollId, salt,  true);


        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION() + 1);

        vm.expectRevert("Reveal stage not active");
        vm.prank(voter1);
        pr.revealVote(pollId, salt,  true);
     }

    function test_NoCommittedVote() public {
        uint salt = 69;
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.expectRevert("No vote committed");
        vm.prank(voter1);
        pr.revealVote(pollId, salt,  true);
    }

    function test_VoteAlreadyRevealed() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  1);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt,  true);

        vm.expectRevert("Already revealed a vote");
        vm.prank(voter1);
        pr.revealVote(pollId, salt,  true);
    }

    function test_CommittedVoteDoesntMatch() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  1);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.expectRevert("Does not match committed vote");
        vm.prank(voter1);
        pr.revealVote(pollId, salt,  false);

        vm.expectRevert("Does not match committed vote");
        vm.prank(voter1);
        pr.revealVote(pollId, 420,  true);
    }

    /*
        Resolve poll
     */

    function testResolvePoll() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  1);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt, true);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION());

        pr.resolvePoll(pollId);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);

        assertEq(poll.winnerAddress, proposer);
        assertEq(poll.resolved, true);
        assertEq(poll.passed, true);
        assertEq(poll.rewardPool, 0);
     }

    function testResolvePollChallenge() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  30);

        uint salt2 = 420;
        bytes32 secretVote2 = keccak256(abi.encodePacked(false, salt2));

        vm.prank(voter2);
        pr.commitVote(pollId, secretVote2,  50);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt, true);

        vm.prank(voter2);
        pr.revealVote(pollId, salt2, false);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION());

        pr.resolvePoll(pollId);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);

        assertEq(poll.winnerAddress, challenger);
        assertEq(poll.resolved, true);
        assertEq(poll.passed, false);
        assertEq(poll.rewardPool, 30);
     }

    function test_pollHasntEnded() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  1);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt, true);

        vm.expectRevert("Poll has not ended");
        pr.resolvePoll(pollId);
    }

    function test_pollHasntAlreadyBeenResolved() public {
        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  1);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt, true);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION());

        pr.resolvePoll(pollId);

        vm.expectRevert("Poll has already been resolved");
        pr.resolvePoll(pollId);

    }

    function testWithdrawBalance() public {
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  10);

        uint salt2 = 420;
        bytes32 secretVote2 = keccak256(abi.encodePacked(false, salt2));
        vm.prank(voter2);
        pr.commitVote(pollId, secretVote2,  5);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt, true);

        vm.prank(voter2);
        pr.revealVote(pollId, salt2, false);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION());

        pr.resolvePoll(pollId);

        assertEq(token.balanceOf(voter1), 90);

        vm.prank(voter1);
        pr.withdrawBalance(pollId);

        assertEq(token.balanceOf(voter1), 105);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);

        assertEq(pr.balances(pollId, voter1), 0);
        assertEq(poll.winnerWithdrawalCount, 1);
        assertEq(poll.withdrawnRewardAmount, 5);
    }

    function testWithdrawBalanceMultipleWinningVotersTenLosingVotes() public {
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  70);

        uint salt2 = 420;
        bytes32 secretVote2 = keccak256(abi.encodePacked(true, salt2));
        vm.prank(voter2);
        pr.commitVote(pollId, secretVote2,  30);

        uint salt3 = 4444;
        bytes32 secretVote3 = keccak256(abi.encodePacked(false, salt3));
        vm.prank(voter3);
        pr.commitVote(pollId, secretVote3,  10);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt, true);

        vm.prank(voter2);
        pr.revealVote(pollId, salt2, true);

        vm.prank(voter3);
        pr.revealVote(pollId, salt3, false);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION());

        pr.resolvePoll(pollId);

        assertEq(token.balanceOf(voter1), 30);
        assertEq(token.balanceOf(voter2), 70);
        assertEq(token.balanceOf(voter3), 90);

        vm.prank(voter1);
        pr.withdrawBalance(pollId);

        assertEq(token.balanceOf(voter1), 107);


        vm.prank(voter2);
        pr.withdrawBalance(pollId);

        assertEq(token.balanceOf(voter2), 103);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);

        assertEq(pr.balances(pollId, voter2), 0);
        assertEq(poll.winnerWithdrawalCount, 2);
        assertEq(poll.withdrawnRewardAmount, 10);
    }

    function testWithdrawBalanceMultipleWinningVotersFiveLosingVotes() public {
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  70);

        uint salt2 = 420;
        bytes32 secretVote2 = keccak256(abi.encodePacked(true, salt2));
        vm.prank(voter2);
        pr.commitVote(pollId, secretVote2,  30);

        uint salt3 = 4444;
        bytes32 secretVote3 = keccak256(abi.encodePacked(false, salt3));
        vm.prank(voter3);
        pr.commitVote(pollId, secretVote3,  5);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt, true);

        vm.prank(voter2);
        pr.revealVote(pollId, salt2, true);

        vm.prank(voter3);
        pr.revealVote(pollId, salt3, false);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION());

        pr.resolvePoll(pollId);

        assertEq(token.balanceOf(voter1), 30);
        assertEq(token.balanceOf(voter2), 70);
        assertEq(token.balanceOf(voter3), 95);

        vm.prank(voter1);
        pr.withdrawBalance(pollId);

        assertEq(token.balanceOf(voter1), 103);

        vm.prank(voter2);
        pr.withdrawBalance(pollId);

        assertEq(token.balanceOf(voter2), 101);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);

        assertEq(pr.balances(pollId, voter2), 0);
        assertEq(poll.winnerWithdrawalCount, 3);
        assertEq(poll.withdrawnRewardAmount, 5);


        assertEq(token.balanceOf(proposer), 101);
    }

    function test_Withdraw_pollHasNotEnded() public {
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  70);

        uint salt2 = 420;
        bytes32 secretVote2 = keccak256(abi.encodePacked(true, salt2));
        vm.prank(voter2);
        pr.commitVote(pollId, secretVote2,  30);

        uint salt3 = 4444;
        bytes32 secretVote3 = keccak256(abi.encodePacked(false, salt3));
        vm.prank(voter3);
        pr.commitVote(pollId, secretVote3,  10);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt, true);

        vm.prank(voter2);
        pr.revealVote(pollId, salt2, true);

        vm.prank(voter3);
        pr.revealVote(pollId, salt3, false);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION());

        vm.prank(voter1);
        vm.expectRevert("Poll has not ended");
        pr.withdrawBalance(pollId);
    }

    function test_Withdraw_hasNotRevealedVote() public {
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  70);

        uint salt2 = 420;
        bytes32 secretVote2 = keccak256(abi.encodePacked(true, salt2));
        vm.prank(voter2);
        pr.commitVote(pollId, secretVote2,  30);

        uint salt3 = 4444;
        bytes32 secretVote3 = keccak256(abi.encodePacked(false, salt3));
        vm.prank(voter3);
        pr.commitVote(pollId, secretVote3,  10);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter2);
        pr.revealVote(pollId, salt2, true);

        vm.prank(voter3);
        pr.revealVote(pollId, salt3, false);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION());

        pr.resolvePoll(pollId);

        vm.prank(voter1);
        vm.expectRevert("User did not reveal vote");
        pr.withdrawBalance(pollId);
    }

    function test_Withdraw_didNotVoteForWinner() public {
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  70);

        uint salt2 = 420;
        bytes32 secretVote2 = keccak256(abi.encodePacked(true, salt2));
        vm.prank(voter2);
        pr.commitVote(pollId, secretVote2,  30);

        uint salt3 = 4444;
        bytes32 secretVote3 = keccak256(abi.encodePacked(false, salt3));
        vm.prank(voter3);
        pr.commitVote(pollId, secretVote3,  10);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt, true);

        vm.prank(voter2);
        pr.revealVote(pollId, salt2, true);

        vm.prank(voter3);
        pr.revealVote(pollId, salt3, false);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION());

        pr.resolvePoll(pollId);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);

        assertEq(poll.totalDeposits, 110);
        assertEq(poll.rewardPool, 10);

        vm.prank(voter3);
        vm.expectRevert("User did not vote for winner party");
        pr.withdrawBalance(pollId);
    }

    function test_Withdraw_hasNoBalance() public {
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));
        vm.prank(voter1);
        pr.commitVote(pollId, secretVote,  70);

        uint salt2 = 420;
        bytes32 secretVote2 = keccak256(abi.encodePacked(true, salt2));
        vm.prank(voter2);
        pr.commitVote(pollId, secretVote2,  30);

        uint salt3 = 4444;
        bytes32 secretVote3 = keccak256(abi.encodePacked(false, salt3));
        vm.prank(voter3);
        pr.commitVote(pollId, secretVote3,  10);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + 1);

        vm.prank(voter1);
        pr.revealVote(pollId, salt, true);

        vm.prank(voter2);
        pr.revealVote(pollId, salt2, true);

        vm.prank(voter3);
        pr.revealVote(pollId, salt3, false);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION());

        pr.resolvePoll(pollId);

        vm.prank(voter1);
        pr.withdrawBalance(pollId);

        vm.prank(voter1);
        vm.expectRevert("User has no balance to withdraw");
        pr.withdrawBalance(pollId);
    }

     function test_NoOneVoted() public {
        uint pollId = pr.createPoll(address(token) ,proposer, challenger);

        vm.warp(block.timestamp + pr.COMMIT_DURATION() + pr.REVEAL_DURATION() + 1);

        pr.resolvePoll(pollId);

        PollRegistry.Poll memory poll = pr.getPoll(pollId);

        assertEq(poll.totalDeposits, 0);
        assertEq(poll.passed, false);
    }
}
