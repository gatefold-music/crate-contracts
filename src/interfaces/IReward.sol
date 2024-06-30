// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

abstract contract IReward is ERC165 {
    function rewardPoolShare(uint _rewardPoolAmount, uint _userStakeAmount, uint _totalStakeAmount) public virtual pure returns (uint);
}