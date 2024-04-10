// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import {CurationToken} from "./CurationToken.sol";

contract CurationTokenFactory is Ownable {
    address public curationTokenImplementation;

    event newCrate(address curationToken, address owner);

    constructor(address _curationTokenImplementation) {
        curationTokenImplementation = _curationTokenImplementation;
    }
    function deployCurationToken(string memory _name, string memory _symbol, address _owner) public onlyOwner returns (address) {
        address newTokenAddress = Clones.clone(curationTokenImplementation);
        CurationToken(newTokenAddress).initialize(_name, _symbol, _owner);

        emit newCrate(newTokenAddress, _owner);
        return newTokenAddress;
    }
}