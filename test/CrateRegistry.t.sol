// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import {CrateRegistry} from "../src/CrateRegistry.sol";
import {CurationToken} from "../src/CurationToken.sol";
import {PollRegistry} from "../src/PollRegistry.sol";
import {Crate} from "../src/Crate.sol";


contract CrateRegistryTest is Test {
    CrateRegistry public crateRegistry;
    CurationToken public crateToken;
    PollRegistry public pollRegistry;
    Crate public crate;
    address public ownerAddress = address(0x12345);


    function setUp() public {
        crateRegistry = new CrateRegistry();
        pollRegistry = new PollRegistry();

        vm.prank(ownerAddress);
        crateToken = new CurationToken();
        crateToken.initialize("CRATE TOKEN", "CRATE", ownerAddress);

        vm.prank(ownerAddress);
        crate = new Crate("HIP-HOP", "Are you talking to me? You must be talking to me... ", address(crateToken), address(pollRegistry), 10);

        // vm.prank(ownerAddress);
        // crate.setAdmin(address(crateRegistry));
    }

    function testOpen() public  {
        // console2.log(address(crate.token()));

        // vm.prank(ownerAddress);
        // crateRegistry.openAccess(address(crate));

        // console2.log(address(crate.token()));
    }

    function testLoop() public {
        // bytes32 b = bytes32("adsfasdfasdfasdfsd");
        // bytes32[] memory list = new bytes32[](100);
        // CrateRegistry.NewList[] memory listings = new CrateRegistry.NewList[](30);
        // for (uint n; n <30;n++) {
        //     list[n] = b;
        //     listings[n] = CrateRegistry.NewList({listHash: b, data: "asdfsdf"});
        // }
        

        // crateRegistry.tryLoop(listings);
    }

    function testPropose() public  {
        // console2.log(address(crate.token()));

        // vm.prank(ownerAddress);
        // crate.propose(address(crate));

        // console2.log(address(crate.token()));
    }

}
