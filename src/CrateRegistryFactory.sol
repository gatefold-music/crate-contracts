// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;
import {CrateRegistry} from "./CrateRegistry.sol";
import {Crate} from "./Crate.sol";


contract CrateRegistryFactory {
    uint public registryId;
    
    /*
     *
     * Mappings
     *
     */
    mapping(uint => address) public factories; // This mapping holds all deployed crates
    mapping(uint => address) public crates; // This mapping holds all deployed crates

    event newRegistryFactory(address factoryAddress);

    constructor() {}

    function deployCrate(string memory _name, string memory _description, address _token, address _voting, uint _minDeposit) public {
        Crate registry = new Crate(_name, _description, _token, _voting, _minDeposit);
        // registry.transferOwnership(msg.sender); ?????

        address registryAddress = address(registry);

        crates[++registryId] = registryAddress;
        emit newRegistryFactory(registryAddress);
    }

    function deployCrateFactory() public {

    }

    function tipYourCurator(address _crateAddress, bytes32 _recordHash) public payable {
        Crate crate = Crate(_crateAddress);
        (bool listed, address owner) = crate.isRecordListed(_recordHash);
        
        require(listed, "Listing does not exist");

        address payable recipient = payable(owner);
        recipient.transfer(msg.value);
    }

    function tipYourCurationist(address _crateAddress) public payable {
        Crate crate = Crate(_crateAddress);
        address payable recipient = payable(crate.owner());
        recipient.transfer(msg.value);
    }
}
