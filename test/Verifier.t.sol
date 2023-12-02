// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../src/VerifySignature.sol";
import "../src/Reward.sol";


contract Verifier is Test {
    VerifySignature verifier;
    address owner = address(0x24618bD401Cb6d18a5b79398cefd8E001A0Ce818);
    function setUp() public {
        verifier = new VerifySignature();
        verifier.transferOwnership(owner);
    }

    function testVerifier() public {
        bytes memory sig = bytes("0x2458409bd33f905c83a0d73a670ab9b610c3f2655fdffa9f871dc2a5a637fe880319fb54511ed386e198e03321d21cd487c8a94df00c5118d6a32e9d83abfb071c");
        verifier.verify("something", sig);
    }

}
