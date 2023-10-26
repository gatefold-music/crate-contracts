// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console2} from "forge-std/Test.sol";
import "../src/Reward.sol";


contract RewardTest is Test {
    function setUp() public {
    }

    function testReward() public {

        assertEq(Reward.rewardPoolShare(10, 70, 100), 7);

        assertEq(Reward.rewardPoolShare(1, 2, 2), 1);

        assertEq(Reward.rewardPoolShare(0, 1, 1), 0);

    }

}
