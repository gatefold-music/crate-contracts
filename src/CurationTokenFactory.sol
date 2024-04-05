// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import {CurationToken} from "./CurationToken.sol";

contract CurationTokenFactory is Ownable {
    address public curationTokenImplementation;

    constructor(address _curationTokenImplementation) {
        curationTokenImplementation = _curationTokenImplementation;
    }
    function deployToken() public onlyOwner returns (address) {
        address newTokenAddress = Clones.clone(curationTokenImplementation);
        return newTokenAddress;
    }
}