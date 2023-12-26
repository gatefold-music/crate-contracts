// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/access/Ownable.sol";

contract TestContract is Ownable {
    string public testString;
    bytes private contents;
    constructor(bytes memory _contents) {
        contents = _contents;
        testString = "some random test string";
    }
    function readContents() public onlyOwner view returns (bytes memory) {
        return contents;
    }

    function writeContents(bytes memory _newContents) public {
        contents = _newContents;
    }

    function writeTestString(string memory _contents) public {
        testString = _contents;
    }
}