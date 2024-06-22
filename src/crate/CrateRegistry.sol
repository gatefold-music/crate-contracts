// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {Crate} from "./Crate.sol";

contract CrateRegistry {
    address public crateImplementation;

    uint public crateId;
    
    mapping(uint => address) public crates; // This mapping holds all deployed crates

    event CrateCreated(address indexed crateAddress, address indexed owner, uint crateId);

    constructor(address _crateImplementation){
        crateImplementation = _crateImplementation;
    }

    function deployCrate(string memory _crateInfo, address _token, address _voting, uint _minDeposit, address _owner) public {
        address newCrateAddress = Clones.clone(crateImplementation);

        Crate(newCrateAddress).initialize(_crateInfo, _token, _voting, _minDeposit, _owner);

        uint newCrateId = ++crateId;

        crates[newCrateId] = address(newCrateAddress);
        emit CrateCreated(newCrateAddress, _owner, newCrateId);
    }
}
