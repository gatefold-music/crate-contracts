// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;
import "../interfaces/IAffinity.sol";
import {ERC1155} from "openzeppelin-contracts/contracts/token/ERC1155/ERC1155.sol";


contract Affinity is IAffinity {

    address tokenAddress;

    mapping(address => uint256) public tokenIds;
    mapping(uint256 => address) public addresses;

    uint256 tokenIdCounter;

    constructor(address _tokenAddress) {
        tokenAddress = _tokenAddress;
    }

    function makeLove(string memory _crateInfo, bytes memory _proof) public {
        // set up new token with metadata url and auth? 
        uint256 newTokenId = ++tokenIdCounter;
        tokenIds[msg.sender] = newTokenId;
        addresses[newTokenId] = msg.sender;
    }


    function showLove(uint256 _amount, address _recipient) public override {
        if (tokenIds[msg.sender] == 0) revert TokenIdNonExistent();
        uint256 tokenId = tokenIds[msg.sender];

        // perform mint somehow
    }

    function haveLove() public view override returns (bool) {
        return tokenIds[msg.sender] > 0 ? true : false;
    }
}