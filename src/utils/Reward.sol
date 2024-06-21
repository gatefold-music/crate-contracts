// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/*
 * @title Reward Library
 * @notice Stand alone library to calculate reward pools for given amount
 */
contract Reward {
    /*
     * @dev Calculates a user's reward pool cut based on user's contribution to total staked amount
     * @notice This does not use floating point so there may be some remnants leftover 
     * @param _rewardPoolAmount the reward pool amount to divvy up
     * @param _userStakeAmount the user contribution amount to _totalStakeAmount 
     * @param _totalStakeAmount the total staked amount, not including reward pool
     */
    function rewardPoolShare(uint _rewardPoolAmount, uint _userStakeAmount, uint _totalStakeAmount) public pure returns (uint) {
        return (_rewardPoolAmount * _userStakeAmount) / _totalStakeAmount;
    }
}