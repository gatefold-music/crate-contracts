// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "./IAffinity.sol";
abstract contract IAffinityManager {
    address public affinityAddress;

    error AffinityManagerNotSetup();

    function showLove(uint256 _amount) public {
        if (affinityAddress == address(0)) {
            revert AffinityManagerNotSetup();
        }
        IAffinity(affinityAddress).showLove(_amount, msg.sender);
    }

    function haveLove() public view returns (address, uint256) {
        if (affinityAddress == address(0)) return (address(0), 0);
        (address _address, uint256 _tokenId) = IAffinity(affinityAddress).haveLove(address(this));
        return (_address, _tokenId);
    }
}