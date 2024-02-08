// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Crate} from "../../src/Crate.sol";
import {CrateRegistry} from "../../src/CrateRegistry.sol";
import {CrateToken} from "../../src/CrateToken.sol";
import {PollRegistry} from "../../src/PollRegistry.sol";


contract CrateTest is Test {
    CrateToken public crateToken;
    PollRegistry public pollRegistry;
    Crate public crate;
    address public ownerAddress = address(0x12345);
    address public spenderAddress = address(0x69420);
    address public challengerAddress = address(0x44444);

    event RecordAdded(bytes32 indexed recordHash, uint deposit, string data, address indexed applicant, uint listExpiry, bool isPrivate);
    event Application(bytes32 indexed recordHash, uint deposit, string data, address indexed applicant, uint applicationExpiry, bool isPrivate);
    event RecordRemoved(bytes32 indexed recordHash);


    function setUp() public {
        pollRegistry = new PollRegistry();

        vm.prank(ownerAddress);
        crateToken = new CrateToken("CRATE TOKEN", "CRATE");

        vm.prank(ownerAddress);
        crate = new Crate("HIP-HOP", "A List of cool hip hop tracks", address(crateToken), address(pollRegistry), 10);

        vm.prank(ownerAddress);
        crateToken.mint(spenderAddress, 1000);

        vm.prank(ownerAddress);
        crateToken.mint(challengerAddress, 1000);

        vm.prank(spenderAddress);
        crateToken.maxApproval(address(crate));

        vm.prank(challengerAddress);
        crateToken.maxApproval(address(crate));

        vm.prank(address(crate));
        crateToken.maxApproval(address(crate));
    }

    function testCreateCrate() public {
        assertEq(crate.name(), "HIP-HOP");
        assertEq(crate.description(), "A List of cool hip hop tracks");
        assertEq(crate.minDeposit(), 10);
        assertEq(crate.appDuration(), 0);
        assertEq(crate.listDuration(), 0);
        assertEq(crate.listLength(), 0);
        assertEq(crate.maxListLength(), type(uint256).max);

        assertEq(address(crate.token()), address(crateToken));
        assertEq(address(crate.pollRegistry()), address(pollRegistry));
    }
    function testPropose() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, 0, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

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
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.expectRevert("Hash does not match data string");
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, "some wrong value that does not match the hashed value");

        vm.expectRevert("Amount does not meet crate minimum");
        vm.prank(spenderAddress);
        crate.propose(hashedValue, 9, value);

        vm.expectRevert("Insufficient token balance");
        vm.prank(spenderAddress);
        crate.propose(hashedValue, 2000, value);

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

        vm.expectRevert("Record already exists");
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

        vm.prank(ownerAddress);
        crate.sealCrate();

        vm.expectRevert("Crate has been sealed close");
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);
    }

    function test_Propose_MaxLengthReached() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        string memory value2 = "Another fake list item";
        bytes32 hashedValue2 = bytes32("Another fake list item");
        uint minDeposit2 = 15;

        vm.prank(ownerAddress);
        crate.updateMaxLength(1);

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

        vm.expectRevert("Exceeds max length");
         vm.prank(spenderAddress);
        crate.propose(hashedValue2, minDeposit2, value2);
    }

    function testProposeWithAppDuration() public {
        uint NEW_APP_DURATION = 86400; // one day

        vm.prank(ownerAddress);
        crate.updateAppDuration(NEW_APP_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;


        // test application proposal
        vm.expectEmit(true, true, true, true);
        emit Application(hashedValue, minDeposit, value, spenderAddress, block.timestamp + NEW_APP_DURATION, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

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

        vm.prank(ownerAddress);
        crate.updateAppDuration(NEW_APP_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;


        vm.expectRevert("Record does not exist");
        vm.prank(spenderAddress);
        crate.resolveApplication(hashedValue);
    }

    function test_ResolveApp_recordAlreadyAllowListed() public {
        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

        vm.expectRevert("Record already allow listed");
        vm.prank(spenderAddress);
        crate.resolveApplication(hashedValue);
    }

    function test_ResolveApp_recordIsChallenged() public {
        uint NEW_APP_DURATION = 86400; // one day

        vm.prank(ownerAddress);
        crate.updateAppDuration(NEW_APP_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

        vm.prank(challengerAddress);
        crate.challenge(hashedValue, 10, challengerAddress);

        vm.expectRevert("Challenge will resolve listing");
        vm.prank(spenderAddress);
        crate.resolveApplication(hashedValue);
    }

    function test_ResolveApp_applicationHasNotExpired() public {
        uint NEW_APP_DURATION = 86400; // one day

        vm.prank(ownerAddress);
        crate.updateAppDuration(NEW_APP_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

        vm.expectRevert("Application duration has not expired");
        vm.prank(spenderAddress);
        crate.resolveApplication(hashedValue);
    }

    function test_ResolveApp_listLengthReached() public {
        vm.prank(ownerAddress);
        crate.updateMaxLength(1);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

        uint NEW_APP_DURATION = 86400; // one day

        vm.prank(ownerAddress);
        crate.updateAppDuration(NEW_APP_DURATION);

        string memory value2 = "A fake list item 2";
        bytes32 hashedValue2 = bytes32("A fake list item 2");
        uint minDeposit2 = 10;

        vm.prank(spenderAddress);
        crate.propose(hashedValue2, minDeposit2, value2);

        vm.warp(block.timestamp + NEW_APP_DURATION + 1);

        vm.expectRevert("Exceeds max length");
        vm.prank(spenderAddress);
        crate.resolveApplication(hashedValue2);
    }



    function testProposeWithListDuration() public {
        uint NEW_LIST_DURATION = 86400; // one day

        vm.prank(ownerAddress);
        crate.updateListDuration(NEW_LIST_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        uint ts = block.timestamp + NEW_LIST_DURATION;
        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, ts, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

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

        vm.prank(ownerAddress);
        crate.updateListDuration(NEW_LIST_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        uint ts = block.timestamp + NEW_LIST_DURATION;
        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, ts, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

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

        vm.prank(ownerAddress);
        crate.updateListDuration(NEW_LIST_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        uint ts = block.timestamp + NEW_LIST_DURATION;
        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, ts, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

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

        vm.prank(ownerAddress);
        crate.updateListDuration(NEW_LIST_DURATION);

        string memory value = "A fake list item";
        bytes32 hashedValue = bytes32("A fake list item");
        uint minDeposit = 10;

        uint ts = block.timestamp + NEW_LIST_DURATION;

        vm.expectEmit(true, true, true, true);
        emit RecordAdded(hashedValue, minDeposit, value, spenderAddress, ts, false);
        vm.prank(spenderAddress);
        crate.propose(hashedValue, minDeposit, value);

        Crate.Record memory record = crate.getRecord(hashedValue);
        assertEq(record.listingExpiry, ts);
        assertEq(crate.listLength(), 1);

        vm.expectRevert("Record can only be removed by owner, challenge or if expired");
        crate.removeRecord(hashedValue);

        vm.warp(ts - 1);

        vm.expectRevert("Record can only be removed by owner, challenge or if expired");
        crate.removeRecord(hashedValue);
    }

}