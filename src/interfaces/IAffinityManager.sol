// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "./IAffinity.sol";
abstract contract IAffinityManager {
    address affinityAddress;

    error AffinityManagerNotSetup();

    function showLove(uint256 _amount) public {
        if (affinityAddress != address(0)) {
            revert AffinityManagerNotSetup();
        }
        IAffinity(affinityAddress).showLove(_amount, msg.sender);
    }

    function haveLove() public view returns (bool) {
        if (affinityAddress != address(0)) return false;
        bool doesHaveLove = IAffinity(affinityAddress).haveLove();
        return doesHaveLove;
    }
}