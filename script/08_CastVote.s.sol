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
// forge script CastVoteScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY -vv --skip test
// to broadcast, add --broadcast flag

contract CastVoteScript is Script {
    address public publicKey = vm.envAddress("PUBLIC_KEY");
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");


    function castVote(GovernorBravoDelegate delegateInterface, uint256 proposalId, uint8 support) public {
        vm.startBroadcast(vm.envUint("USER1_PRIVATE_KEY"));
        delegateInterface.castVote(proposalId, support);
        vm.stopBroadcast();
    }
    function run() external {
        GovernorBravoDelegate delegateInterface = GovernorBravoDelegate(vm.envAddress("GOVERNOR_BRAVO"));
        this.castVote(delegateInterface, 3, 2);
    }

    // add this to be excluded from coverage report
    function test() public {}
}
