// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/VerifySignature.sol";

// source .env
// forge script script/DeployVerifier.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv

// forge script script/DeployErc20.s.sol:DeployScript --rpc-url $MAINNET_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv


contract DeployScript is Script {

    function setUp() public {
    }

    function run() external {
        vm.startBroadcast();

        VerifySignature sigVerify = new VerifySignature();

        vm.stopBroadcast();
    }
}
