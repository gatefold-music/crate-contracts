// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "openzeppelin-contracts/contracts/utils/introspection/ERC165.sol";
import {ZoraCreator1155Impl} from "zora-protocol/nft/ZoraCreator1155Impl.sol";

contract Affinity is IAffinity {
    constructor() {

    }
    function showLove(address _recipient) public {
       ZoraCreator1155Impl(0x).adminMint(_recipient);
    }
}