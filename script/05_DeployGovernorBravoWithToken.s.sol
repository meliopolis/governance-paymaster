// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Uni} from "uniswap-gov/Uni.sol";
import {Timelock} from "uniswap-gov/Timelock.sol";
import {GovernorBravoDelegate} from "uniswap-gov/GovernorBravoDelegate.sol";
import {GovernorBravoDelegator} from "uniswap-gov/GovernorBravoDelegator.sol";
import {GovernorBravoDelegateStorageV1} from "uniswap-gov/GovernorBravoInterfaces.sol";

// To run:
// forge script DeployGovernorBravoWithTokenScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify -vv --skip test
// to broadcast, add --broadcast flag

contract DeployGovernorBravoWithTokenScript is Script {
    address public publicKey = vm.envAddress("PUBLIC_KEY");
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    function initialSetup() external {
        vm.startBroadcast(this.privateKey());

        // 1. deploy uni token
        Uni uni = new Uni(this.publicKey(), this.publicKey(), block.timestamp);
        console.log("Uni deployed at: ", address(uni));

        // 2. deploy timelock
        Timelock timelock = new Timelock(this.publicKey(), 0);
        console.log("Timelock deployed at: ", address(timelock));

        // 3. deploy delegate
        GovernorBravoDelegate delegate = new GovernorBravoDelegate();
        console.log("Delegate deployed at: ", address(delegate));

        // 4. deploy delegator
        GovernorBravoDelegator delegator = new GovernorBravoDelegator(
            address(timelock),
            address(uni),
            this.publicKey(), // admin
            address(delegate),
            80640, // votingPeriod in blocks
            1, // votingDelay
            1e18
        ); // proposalThreshold
        console.log("Delegator deployed at: ", address(delegator));

        GovernorBravoDelegate delegateInterface = GovernorBravoDelegate(address(delegator));

        // 5. initiate GovernorBravo
        delegateInterface._initiate(1);
        console.log("GovernorBravo initiated");

        vm.stopBroadcast();
    }


    function run() external {
        this.initialSetup();
    }

    // add this to be excluded from coverage report
    function test() public {}
}
