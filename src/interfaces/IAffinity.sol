// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";

abstract contract IAffinity is ERC165 {
    error TokenIdNonExistent();
    function facilitateMint(uint256 _amount, address _recipient) public virtual;
}