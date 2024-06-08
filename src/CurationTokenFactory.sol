// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;

import "openzeppelin-contracts/contracts/proxy/Clones.sol";
import "openzeppelin-contracts/contracts/access/Ownable.sol";
import {CurationToken} from "./CurationToken.sol";

contract CurationTokenFactory is Ownable {
    address public curationTokenImplementation;

    uint public tokenId;

    mapping(uint => address) public tokens; // This mapping holds all deployed curation tokens

    event NewCurationToken(address curationToken, address owner);

    constructor(address _curationTokenImplementation) {
        curationTokenImplementation = _curationTokenImplementation;
    }
    function deployCurationToken(string memory _name, string memory _symbol, address _owner, uint initAmount) public onlyOwner returns (address) {
        address newTokenAddress = Clones.clone(curationTokenImplementation);
        CurationToken token = CurationToken(newTokenAddress);
        
        address tokenOwner = initAmount > 0 ? address(this) : _owner;
        token.initialize(_name, _symbol, tokenOwner);

        tokens[++tokenId] = newTokenAddress;

        if (initAmount > 0) {
            token.mint(_owner, initAmount);
            token.transferOwnership(_owner);
        }

        emit NewCurationToken(newTokenAddress, _owner);
        return newTokenAddress;
    }
}