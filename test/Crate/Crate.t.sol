// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Crate} from "../../src/crate/Crate.sol";
import {CrateRegistry} from "../../src/crate/CrateRegistry.sol";
import {CurationToken} from "../../src/token/CurationToken.sol";
import {PollRegistry} from "../../src/poll/PollRegistry.sol";


contract CrateTest is Test {
    CurationToken public crateToken;
    PollRegistry public pollRegistry;
    Crate public crate;
    address public ownerAddress = address(0x12345);
    address public spenderAddress = address(0x69420);
    address public challengerAddress = address(0x44444);
    address public voterAddress = address(0x77777);

    event RecordAdded(bytes32 indexed recordHash, uint deposit, string data, address indexed applicant, uint listExpiry, bool isPrivate);
    event Application(bytes32 indexed recordHash, uint deposit, string data, address indexed applicant, uint applicationExpiry, bool isPrivate);
    event RecordRemoved(bytes32 indexed recordHash);
    event Challenge(bytes32 indexed recordHash, uint challengeId, address indexed challenger);
    event ChallengeSucceeded(bytes32 indexed recordHash);

    function setUp() public {
        bytes memory empty;

        console2.logBytes(empty);
        console2.log("zone in");
        pollRegistry = new PollRegistry();

        vm.prank(ownerAddress);
        crateToken = new CurationToken();
        crateToken.initialize("CRATE TOKEN", "CRATE", ownerAddress);


        vm.prank(ownerAddress);
        crate = new Crate();
        crate.initialize("HIP-HOP", address(crateToken), address(pollRegistry), 10, address(this));

        vm.prank(ownerAddress);
        crateToken.mint(spenderAddress, 1000);

        vm.prank(ownerAddress);
        crateToken.mint(challengerAddress, 1000);

        vm.prank(ownerAddress);
        crateToken.mint(voterAddress, 1000);

        vm.prank(spenderAddress);
        crateToken.maxApproval(address(crate));

        vm.prank(challengerAddress);
        crateToken.maxApproval(address(crate));

        vm.prank(address(crate));
        crateToken.maxApproval(address(crate));

        vm.prank(address(voterAddress));
        crateToken.maxApproval(address(crate));

        vm.prank(address(voterAddress));
        crateToken.maxApproval(address(pollRegistry));
    }

    function testCreateCrate() public {
        assertEq(crate.crateInfo(), "HIP-HOP");
        assertEq(crate.minDeposit(), 10);
        assertEq(crate.appDuration(), 0);
        assertEq(crate.listDuration(), 0);
        assertEq(crate.listLength(), 0);
        assertEq(crate.maxListLength(), type(uint256).max);

        assertEq(crate.tokenAddress(), address(crateToken));

        assertEq(crate.tokenAddress(), address(crateToken));
        assertEq(crate.pollRegistryAddress(), address(pollRegistry));
    }
    function testPropose() public {
        console2.log(type(uint256).max);

        string memory value = "A fake list item";
        bytes memory packd = abi.encodePacked(value);
        console2.log('packed');
        console2.logBytes(packd);
        bytes32 khash = keccak256(packd);
        console2.log('keckak hash packed');
        console2.logBytes32(khash);

        bytes32 hashedValue = bytes32(khash);
        console2.log('bytes32 keck hash packed');
        console2.logBytes32(hashedValue);
 
        uint minDeposit = 10;

        console2.logBytes(new bytes(0));

        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, 0, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        Crate.Record memory record = crate.getRecord(hashedValue);

        assertEq(record.owner, spenderAddress);
        assertEq(record.deposit, minDeposit);
        assertEq(record.data, value);
        assertEq(record.doesExist, true);
        assertEq(record.tokenAddress, address(crateToken));
        assertEq(record.listed, true);

        assertEq(crate.listLength(), 1);
    }

    function test_ProposeFails() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = keccak256(abi.encodePacked("A fake list item"));
        uint minDeposit = 10;

        vm.expectRevert("Amount does not meet crate minimum");
        vm.prank(spenderAddress);
        crate.propose(hashedValue, 9, value, new bytes(0), false);

        vm.expectRevert("Insufficient token balance");
        vm.prank(spenderAddress);
        crate.propose(hashedValue, 2000, value, new bytes(0), false);

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.expectRevert("Record already exists");
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        crate.sealCrate();

        vm.expectRevert("Crate has been sealed close");
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);
    }

    function test_Propose_MaxLengthReached() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        string memory value2 = "Another fake list item";
        bytes32 hashedValue2 = bytes32("Another fake list item");
        uint minDeposit2 = 15;

        crate.updateMaxLength(1);

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.expectRevert("Exceeds max length");
         vm.prank(spenderAddress);
        crate.propose(hashedValue2, minDeposit2, value2, new bytes(0), false);
    }

    function testProposeWithAppDuration() public {
        uint NEW_APP_DURATION = 86400; // one day

        crate.updateAppDuration(NEW_APP_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;


        // test application proposal
        vm.expectEmit(true, true, true, true);
        emit Application(hashedValue, minDeposit, value, spenderAddress, block.timestamp + NEW_APP_DURATION, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        Crate.Record memory record = crate.getRecord(hashedValue);

        assertEq(record.owner, spenderAddress);
        assertEq(record.deposit, minDeposit);
        assertEq(record.data, value);
        assertEq(record.doesExist, true);
        assertEq(record.tokenAddress, address(crateToken));
        assertEq(record.listed, false);
        assertEq(crate.listLength(), 0);

        // test resolve application
        vm.warp(block.timestamp + NEW_APP_DURATION + 1);
        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, 0, false);
        crate.resolveApplication(hashedValue);

        Crate.Record memory recordAgain = crate.getRecord(hashedValue);
        assertEq(recordAgain.listed, true);
        assertEq(recordAgain.listingExpiry, 0);
    }

    function test_ResolveApp_recordDoesntExist() public {
        uint NEW_APP_DURATION = 86400; // one day

        crate.updateAppDuration(NEW_APP_DURATION);

        bytes32 hashedValue = bytes32("A fake list item");


        vm.expectRevert("Record does not exist");
        vm.prank(spenderAddress);
        crate.resolveApplication(hashedValue);
    }

    function test_ResolveApp_recordAlreadyAllowListed() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.expectRevert("Record already allow listed");
        vm.prank(spenderAddress);
        crate.resolveApplication(hashedValue);
    }

    function test_ResolveApp_recordIsChallenged() public {
        uint NEW_APP_DURATION = 86400; // one day

        crate.updateAppDuration(NEW_APP_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.prank(challengerAddress);
        crate.challenge(hashedValue, 10, challengerAddress);

        vm.expectRevert("Record is in challenged state");
        vm.prank(spenderAddress);
        crate.resolveApplication(hashedValue);
    }

    function test_ResolveApp_applicationHasNotExpired() public {
        uint NEW_APP_DURATION = 86400; // one day

        crate.updateAppDuration(NEW_APP_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.expectRevert("Application duration has not expired");
        vm.prank(spenderAddress);
        crate.resolveApplication(hashedValue);
    }

    function test_ResolveApp_listLengthReached() public {
        crate.updateMaxLength(1);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        uint NEW_APP_DURATION = 86400; // one day

        crate.updateAppDuration(NEW_APP_DURATION);

        string memory value2 = "A fake list item 2";
        bytes32 hashedValue2 = bytes32("A fake list item 2");
        uint minDeposit2 = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue2, minDeposit2, value2, new bytes(0), false);

        vm.warp(block.timestamp + NEW_APP_DURATION + 1);

        vm.expectRevert("Exceeds max length");
        vm.prank(spenderAddress);
        crate.resolveApplication(hashedValue2);
    }



    function testProposeWithListDuration() public {
        uint NEW_LIST_DURATION = 86400; // one day

        crate.updateListDuration(NEW_LIST_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        uint ts = block.timestamp + NEW_LIST_DURATION;
        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, ts, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        Crate.Record memory record = crate.getRecord(hashedValue);

        assertEq(record.owner, spenderAddress);
        assertEq(record.deposit, minDeposit);
        assertEq(record.data, value);
        assertEq(record.doesExist, true);
        assertEq(record.tokenAddress, address(crateToken));
        assertEq(record.listed, true);
        assertEq(record.listingExpiry, ts);
        assertEq(crate.listLength(), 1);
    }

    function testRemoveRecord() public {
        uint NEW_LIST_DURATION = 86400; // one day

        crate.updateListDuration(NEW_LIST_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        uint ts = block.timestamp + NEW_LIST_DURATION;
        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, ts, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        Crate.Record memory record = crate.getRecord(hashedValue);
        assertEq(record.listingExpiry, ts);
        assertEq(crate.listLength(), 1);

        vm.warp(ts + 1);

        vm.expectEmit(true, true, true, true);
        emit RecordRemoved(hashedValue);
        crate.removeRecord(hashedValue);

        Crate.Record memory recordAfter = crate.getRecord(hashedValue);
        assertEq(recordAfter.doesExist, false);
        assertEq(crate.listLength(), 0);
    }

    function test_Remove_isChallenged() public {
        uint NEW_LIST_DURATION = 86400; // one day

        crate.updateListDuration(NEW_LIST_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        uint ts = block.timestamp + NEW_LIST_DURATION;
        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, ts, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.prank(challengerAddress);
        crate.challenge(hashedValue, 10, challengerAddress);

        Crate.Record memory record = crate.getRecord(hashedValue);
        assertEq(record.listingExpiry, ts);
        assertEq(crate.listLength(), 1);

        vm.warp(ts + 1);

        vm.expectRevert("Record is in challenged state");
        crate.removeRecord(hashedValue);
    }

    function test_Remove_cannotRemove() public {
        uint NEW_LIST_DURATION = 86400; // one day

        crate.updateListDuration(NEW_LIST_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        uint ts = block.timestamp + NEW_LIST_DURATION;

        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, ts, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        Crate.Record memory record = crate.getRecord(hashedValue);
        assertEq(record.listingExpiry, ts);
        assertEq(crate.listLength(), 1);

        vm.expectRevert("Record can only be removed by owner, challenge or if expired");
        crate.removeRecord(hashedValue);

        vm.warp(ts - 1);

        vm.expectRevert("Record can only be removed by owner, challenge or if expired");
        crate.removeRecord(hashedValue);
    }

    function testChallenge() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.expectEmit(true, true, true, true);
        emit Challenge(hashedValue, 1, challengerAddress);
        vm.prank(challengerAddress);
        uint pollId = crate.challenge(hashedValue, 10, challengerAddress);

        Crate.Record memory record = crate.getRecord(hashedValue);
        assertEq(record.challengeId, pollId);
        assertEq(record.challenger, challengerAddress);
        assertEq(record.challengerPayoutAddress, challengerAddress);
        assertEq(record.challengeDeposit, 10);
    }

    function test_Challenge_crateIsSealed() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        crate.sealCrate();

        vm.expectRevert("Crate has been sealed close");
        vm.prank(challengerAddress);
        crate.challenge(hashedValue, 10, challengerAddress);
    }

    function test_Challenge_doesNotExist() public {
        bytes32 hashedValue = bytes32("A fake list item");

        vm.expectRevert("Record does not exist");
        vm.prank(challengerAddress);
        crate.challenge(hashedValue, 10, challengerAddress);
    }

    function test_Challenge_InsufficientBalance() public {
        bytes32 hashedValue = bytes32("A fake list item");

        vm.expectRevert("Record does not exist");
        vm.prank(challengerAddress);
        crate.challenge(hashedValue, 2000, challengerAddress);
    }

    function test_Challenge_InsufficientStake() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 20;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.expectRevert("Not enough stake for application.");
        vm.prank(challengerAddress);
        crate.challenge(hashedValue, 10, challengerAddress);
    }

    function test_Challenge_AlreadyChallenged() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.prank(challengerAddress);
        crate.challenge(hashedValue, 10, challengerAddress);

        vm.expectRevert("Record has already been challenged.");
        vm.prank(challengerAddress);
        crate.challenge(hashedValue, 10, challengerAddress);
    }

    function testChallengeResolve() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.prank(challengerAddress);
        uint pollId = crate.challenge(hashedValue, 10, challengerAddress);

        Crate.Record memory r = crate.getRecord(hashedValue);
        assertEq(r.challengeId, pollId);

        vm.warp(block.timestamp + pollRegistry.COMMIT_DURATION() + pollRegistry.REVEAL_DURATION() + 1);

        pollRegistry.resolvePoll(pollId);

        vm.expectEmit(true, true, true, true);
        emit ChallengeSucceeded(hashedValue);
        crate.resolveChallenge(hashedValue);
    }

    function testChallengeResolve_noRecord() public {
        bytes32 hashedValue = bytes32("A fake list item");

        vm.expectRevert("Record does not exist");
        crate.resolveChallenge(hashedValue);
    }


    function testChallengeResolve_noChallenge() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.expectRevert("Has no open challenge");
        crate.resolveChallenge(hashedValue);
    }

    function testChallengeResolve_challengeAlreadyResolved() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.prank(challengerAddress);
        uint pollId = crate.challenge(hashedValue, 10, challengerAddress);

        uint salt = 69;
        bytes32 secretVote = keccak256(abi.encodePacked(true, salt));

        vm.prank(voterAddress);
        pollRegistry.commitVote(pollId, secretVote, 10);

        vm.warp(block.timestamp + pollRegistry.COMMIT_DURATION() + 1);

        vm.prank(voterAddress);
        pollRegistry.revealVote(pollId, salt, true);

        vm.warp(block.timestamp + pollRegistry.COMMIT_DURATION() + pollRegistry.REVEAL_DURATION() + 1);

        pollRegistry.resolvePoll(pollId);

        crate.resolveChallenge(hashedValue);

        vm.expectRevert("Has no open challenge");
        crate.resolveChallenge(hashedValue);
    }

    function testChallengeResolve_pollHasNotEnded() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        vm.prank(challengerAddress);
        crate.challenge(hashedValue, 10, challengerAddress);

        vm.expectRevert("Poll has not ended");
        crate.resolveChallenge(hashedValue);
    }

    function testChallengeResolve_ListLengthReached() public {

        crate.updateMaxLength(2);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value, new bytes(0), false);

        string memory valueTwo = "Another fake list item";
        bytes32 hashedValueTwo = bytes32("Another fake list item");
        uint minDepositTwo = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValueTwo, minDepositTwo, valueTwo, new bytes(0), false);

        vm.prank(challengerAddress);
        uint pollId = crate.challenge(hashedValue, 10, challengerAddress);

        uint salt = 69420;
        bytes32 vote = keccak256(abi.encodePacked(false, salt));
        vm.prank(voterAddress);
        pollRegistry.commitVote(pollId, vote, 100);

        vm.warp(block.timestamp + pollRegistry.COMMIT_DURATION() + 1);

        vm.prank(voterAddress);
        pollRegistry.revealVote(pollId,  69420 , false);

        vm.warp(block.timestamp + pollRegistry.COMMIT_DURATION() + pollRegistry.REVEAL_DURATION() + 1);

        vm.prank(ownerAddress);
        pollRegistry.resolvePoll(pollId);

        // vm.expectRevert("Exceeds max length");
        crate.resolveChallenge(hashedValue);
    }
}