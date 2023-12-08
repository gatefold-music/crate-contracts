// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {Crate} from "../src/Crate.sol";
import {CrateRegistry} from "../src/CrateRegistry.sol";
import {CrateToken} from "../src/CrateToken.sol";
import {PollRegistry} from "../src/PollRegistry.sol";


contract CrateTest is Test {
    CrateRegistry public crateRegistry;
    CrateToken public crateToken;
    PollRegistry public pollRegistry;
    Crate public crate;
    address public ownerAddress = address(0x12345);
    address public spenderAddress = address(0x69420);
    event RecordAdded(bytes32 indexed recordHash, uint indexed ts);


    function setUp() public {
        crateRegistry = new CrateRegistry();
        pollRegistry = new PollRegistry();

        vm.prank(ownerAddress);
        crateToken = new CrateToken("CRATE TOKEN", "CRATE");

        vm.prank(ownerAddress);
        crate = new Crate("HIP-HOP", "Some basic ass description biiiiitch", address(crateToken), address(pollRegistry), 10);

        vm.prank(ownerAddress);
        crateToken.mint(spenderAddress, 100);

        vm.prank(spenderAddress);
        crateToken.maxApproval(address(crate));
    }

    function testSomething() public  {
        bytes32 a = bytes32("a super secret entry");
        bytes32 b = bytes32(0);
        (bytes32 curr, bytes32 prev) = crate.positions(a);
        console2.logBytes32(curr);
        console2.logBytes32(prev);
        // console2.logBytes32(b);
        // string memory b = "some crazy one word password";

        (bytes32 x, bytes32 y) = crate.positions(b);
        console2.logBytes32(curr);
        console2.logBytes32(prev);

        // bytes32 x = keccak256(abi.encodePacked(a, b));
        // console2.log(block.timestamp);


        // uint256 x = type(uint256).max;

        // uint256 r;
        // console2.log(r);
        // require(keccak256(abi.encodePacked(_vote, _salt)) == voteHashes[_pollId][msg.sender]);


        // vm.prank(spenderAddress);
        // crate.propose(a, 10, "ipfs://c");


        // crate.encode(a);


        // vm.expectEmit(true, true, false, true);
        // emit RecordAdded(a, block.timestamp);

        // emit RecordAdded(a, 99);
    }

    function testSomethingAgain() public  {
        bytes32 a = bytes32("adsfasdfasdfasdfsd");
        console2.logBytes32(a);

         vm.prank(spenderAddress);
         crate.propose(a, 10, "adsfasdfasdfasdfsd");

    }


    function testBatchPropose() public {
        // bytes32 a = bytes32("adsfasdfasdfasdfsd");
        // bytes32 b = bytes32("asdf");
        // bytes32 c = bytes32("d");
        // bytes32[] memory list = new bytes32[](3);
        // string[] memory datas = new string[](3);

        // list[0] = a;
        // datas[0]= "ipfs://a";
        // list[1] = b;
        // datas[0]= "ipfs://b";
        // list[2] = c;
        // datas[0]= "ipfs://c";

        // vm.prank(spenderAddress);
        // crate.batchPropose(list, datas, 10);
    }

    function testPropose() public {
        // bytes32 a = bytes32("adsfasdfasdfasdfsd");
        // bytes32 b = bytes32("asdf");
        // bytes32 c = bytes32("d");
        // bytes32[] memory list = new bytes32[](3);
        // string[] memory datas = new string[](3);

        // list[0] = a;
        // datas[0]= "ipfs://a";
        // list[1] = b;
        // datas[0]= "ipfs://b";
        // list[2] = c;
        // datas[0]= "ipfs://c";

        // vm.prank(spenderAddress);
        // crate.propose(bytes32("d"), 10, "ipfs://c");
    }

}