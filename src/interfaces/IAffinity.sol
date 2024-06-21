// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import {ERC165} from "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

abstract contract IAffinity is ERC165 {
    address tokenAddress;

    mapping(address => uint256) public tokenIds;

    error TokenIdNonExistent();

    function showLove(uint256 _amount, address _recipient) public virtual;

    function haveLove(address _crateAddress) public view virtual returns (address, uint256);
}