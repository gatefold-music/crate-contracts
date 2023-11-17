// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;
import {CrateToken} from "./CrateToken.sol";
import {PollRegistry} from "./PollRegistry.sol";
import {Crate} from "./Crate.sol";

contract CrateRegistry {
    event newCrate(address crateAddress);
    function deployCrate(string memory _name, address _token, address _voting, uint _minDeposit) public {
        Crate crate = new Crate(_name, _token, _voting, _minDeposit);
        crate.transferOwnership(msg.sender);
        emit newCrate(address(crate));
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
}
