// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.21;
import { Ownable } from "openzeppelin-contracts/contracts/access/Ownable.sol";
import {CrateToken} from "./CrateToken.sol";
import {PollRegistry} from "./PollRegistry.sol";
import {Crate} from "./Crate.sol";

contract CrateRegistry {
    constructor() {}

    struct NewList {
        bytes32 listHash;
        string data;
    }

    function openAccess(address _crateAddress) public returns (address) {
        Crate crate = Crate(_crateAddress);
        require(msg.sender == crate.owner(), "Caller must be owner to open access");
        CrateToken token = new CrateToken(crate.name(), "CRATE");
        token.mint(msg.sender, 100000);
        token.approveForOwner(msg.sender, _crateAddress);
        token.approveForOwner(msg.sender, address(crate.pollRegistry()));
        token.transferOwnership(msg.sender);
        crate.updateToken(address(token));

        return address(token);
    }      

    function tryLoop(NewList[] memory hashes) public pure returns (uint256 sum) {
        uint length = hashes.length;
        unchecked {
            for (uint256 n =0; n < length;) {
                sum += n;
                n++;
            }
        }
    }

}
