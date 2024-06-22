// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Clones} from "openzeppelin-contracts/contracts/proxy/Clones.sol";
import {CrateRegistry} from "./CrateRegistry.sol";

contract CrateRegistry {
    address public crateRegistryImpl;
    address public crateImpl;

    uint public crateFactoryId;
    
    mapping(uint => address) public crateFactories; // This mapping holds all deployed crate factories

    event CrateRegistryCreated(address crateRegistryAddress, address owner, uint crateFactoryId);

    constructor(address _crateRegistryImpl, address _crateImpl){
        crateRegistryImpl = _crateRegistryImpl;
        crateImpl = _crateImpl;
    }

    function deployCrateRegistry() public {
        address newCrateRegistryAddress = Clones.clone(crateRegistryImpl);

        CrateRegistry(newCrateRegistryAddress).initialize(crateImpl, msg.sender);

        uint newCrateRegistryId = ++crateFactoryId;

        crates[newCrateRegistryId] = address(newCrateRegistryAddress);
        emit CrateRegistryCreated(newCrateRegistryAddress, msg.sender, newCrateRegistryId);
    }
}
