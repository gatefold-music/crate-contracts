// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;
// import {CurationTokenOG} from "./CurationTokenOG.sol";
import {PollRegistry} from "./PollRegistry.sol";
import {Crate} from "./Crate.sol";
import "openzeppelin-contracts/contracts/proxy/Clones.sol";

contract CrateRegistry {
    address public crateImplementation;

    uint public crateId;
    
    mapping(uint => address) public crates; // This mapping holds all deployed crates

    event NewCrate(address crateAddress, address owner, uint crateId);

    constructor(address _crateImplementation){
        crateImplementation = _crateImplementation;
        crateId = 0;
    }

    function destroyContract() external {
        selfdestruct(payable(0x24618bD401Cb6d18a5b79398cefd8E001A0Ce818));
    }

    function deployCrate(string memory _crateInfo, address _token, address _voting, uint _minDeposit, address _owner) public {
        // Crate newCrate = new Crate(_crateInfo, _token, _voting, _minDeposit, _owner);

        address newCrateAddress = Clones.clone(crateImplementation);

        Crate(newCrateAddress).initialize(_crateInfo, _token, _voting, _minDeposit, _owner);

        uint newCrateId = ++crateId;

        crates[newCrateId] = address(newCrateAddress);
        emit NewCrate(newCrateAddress, _owner, newCrateId);
    }

    function tipYourCurator(address _crateAddress, bytes32 _recordHash) public payable {
        Crate crate = Crate(_crateAddress);
        (bool listed, address owner) = crate.isRecordListed(_recordHash);
        
        require(listed, "Listing does not exist");

        address payable recipient = payable(owner);
        recipient.transfer(msg.value);
    }

    // function tipYourCurationist(address _crateAddress) public payable {
    //     Crate crate = Crate(_crateAddress);
    //     address payable recipient = payable(crate.owner());
    //     recipient.transfer(msg.value);
    // }
}
