// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../../src/PollRegistry.sol";
import "../../src/CrateToken.sol";


contract RewardTest is Test {
    uint public constant VOTE_QUORUM = 50; // majority wins
    uint public constant COMMIT_DURATION = 86400; // one day 
    uint public constant REVEAL_DURATION = 86400; // one day 

    PollRegistry public pr;
    address public owner = address(0x69420);
    address public proposer = address(0x12345);
    address public challenger = address(0x67890);

    event PollCreated(uint commitEndDate, uint revealEndDate, uint indexed pollId, address indexed creator);


    CrateToken public token;
    function setUp() public {
        pr = new PollRegistry();

        vm.prank(owner);
        token = new CrateToken("Test Token", "TEST");

         vm.prank(owner);
         token.mint(owner, 1000);

        vm.prank(owner);
        token.mint(owner, 1000);

        token.maxApproval(address(pr));

        vm.prank(owner);
        token.mint(proposer, 100);

        vm.prank(owner);
        token.approveForOwner(proposer, address(pr));


        vm.prank(owner);
        token.mint(challenger, 100);

        vm.prank(owner);
        token.approveForOwner(challenger, address(pr));
    }



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

}
