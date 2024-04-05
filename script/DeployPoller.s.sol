// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console2} from "forge-std/Script.sol";
import "../src/PollRegistry.sol";
import "../src/CurationToken.sol";
import "../src/CurationTokenFactory.sol";

// source .env
// forge script script/DeployPoller.s.sol:DeployScript --rpc-url $SEPOLIA_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv

// forge script script/DeployPoller.s.sol:DeployScript --rpc-url $BASE_SEPOLIA_RPC_URL  --private-key $PRIVATE_KEY --broadcast

// forge script script/DeployErc20.s.sol:DeployScript --rpc-url $MAINNET_RPC_URL  --private-key $PRIVATE_KEY --broadcast --verify --etherscan-api-key $ETHERSCAN_KEY -vvvv

// forge script script/DeployVerifier.s.sol:DeployScript --fork-url http://localhost:8545 \ --sender 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80 --broadcast


contract DeployScript is Script {

    function setUp() public {
    }

    function run() external {
        vm.startBroadcast();

        CurationToken token = new CurationToken("fadsfad", "fasdfs");

        address tokenImpl = address(token);

        console2.log("token impl");
        console2.log(tokenImpl);

        CurationTokenFactory factory = new CurationTokenFactory(tokenImpl);

        console2.log("factory address");
        console2.log(address(factory));

        address newTokenAddress = factory.deployToken();

        console2.log("new token address");
        console2.log(address(newTokenAddress));
        console2.log(CurationToken(newTokenAddress).symbol());

       

        vm.stopBroadcast();
    }
}
