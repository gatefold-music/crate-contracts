// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../src/TestContract.sol";
// forge script script/DeployTCR.s.sol:DeployTCR --fork-url http://localhost:8545 \ --sender 0xa0Ee7A142d267C1f36714E4a8F75612F20a79720 --private-key 0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6 --broadcast


contract TestContractTest is Test {
    TestContract public newContract;
    address public ownerAddress = address(0x12345);
    function setUp() public {
        vm.prank(ownerAddress);
        newContract = new TestContract("hello world");
    }

    function testContents() public {
        vm.prank(ownerAddress);
        bytes memory contents = newContract.readContents();
        console2.logBytes(contents);
    }

}