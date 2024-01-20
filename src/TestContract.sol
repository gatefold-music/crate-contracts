// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract TestContract is Ownable {
    uint public length;

    mapping(uint => string) private records; 

    constructor() {}
    function readContents(uint position) public onlyOwner view returns (string memory) {
        return records[position];
    }

    function writeTestString(uint position, string memory _contents) public onlyOwner {
        records[position] = _contents;
    }

    function writeString(uint position, string memory _contents) public  {
        records[position] = _contents;
    }

    function readString(uint position) public view returns (string memory) {
        return records[position];
    }
}