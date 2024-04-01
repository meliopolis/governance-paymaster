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
// forge script GenerateTokenActivityPreVote --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify -vv --skip test
// to broadcast, add --broadcast flag

contract GenerateTokenActivityPreVote is Script {
    address public publicKey = vm.envAddress("PUBLIC_KEY");
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    function priorVotesHelper(Uni uni, address user) public view {
        uint256 priorVotes = uni.getPriorVotes(user, block.number - 1);
        console.log("address", user);
        console.log("prior votes", priorVotes);
        uint256 numCheckPoints = uni.numCheckpoints(user);
        console.log("num checkpoints", numCheckPoints);
        for (uint32 i = 0; i < numCheckPoints; i++) {
            (uint32 fromBlock, uint96 votes) = uni.checkpoints(user, i);
            console.log("from block", fromBlock);
            console.log("votes", votes);
        }
    }

    function tokenActions(Uni uni, address user1Address, address user2Address) public {
        // 1. transfer uni to other accounts
        vm.startBroadcast(this.privateKey());
        uni.delegate(user1Address);
        uni.transferFrom(this.publicKey(), user1Address, 10_000_000_000_000_000_000);
        uni.transferFrom(this.publicKey(), user2Address, 20_000_000_000_000_000_000);

        // 2. delegate UNI from those accounts to each other
        uni.delegate(user2Address);
        vm.stopBroadcast();
    }

    function UNITest(Uni uni) public {
        vm.startBroadcast(this.privateKey());
        // Uni uni = new Uni(this.publicKey(), this.publicKey(), block.timestamp);

        // test transfer
        uni.transferFrom(this.publicKey(), vm.envAddress("USER1_ADDRESS"), 10_000_000_000_000_000_000);
        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("USER1_PRIVATE_KEY"));
        uni.transferFrom(vm.envAddress("USER1_ADDRESS"), vm.envAddress("USER2_ADDRESS"), 4_000_000_000_000_000_000);
        vm.stopBroadcast();

        console.log("admin balance", uni.balanceOf(this.publicKey()));
        console.log("User1 balance: ", uni.balanceOf(vm.envAddress("USER1_ADDRESS")));
        console.log("User2 balance: ", uni.balanceOf(vm.envAddress("USER2_ADDRESS")));
    }

    function getUNIBalances(Uni uni) public view {
        console.log("admin balance", uni.balanceOf(this.publicKey()));
        console.log("User1 balance: ", uni.balanceOf(vm.envAddress("USER1_ADDRESS")));
        console.log("User2 balance: ", uni.balanceOf(vm.envAddress("USER2_ADDRESS")));
    }

    function run() external {
        address user1Address = vm.envAddress("USER1_ADDRESS"); // EOA for local fork
            // address user1Address = vm.envAddress("AA_ADDRESS"); // AA Wallet
        address user2Address = vm.envAddress("USER2_ADDRESS");

        Uni uni = Uni(vm.envAddress("ERC20_TOKEN"));
        this.tokenActions(uni, user1Address, user2Address);
    }

    // add this to be excluded from coverage report
    function test() public {}
}
