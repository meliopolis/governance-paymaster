// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Uni} from 'uniswap-gov/Uni.sol';
import {Timelock} from 'uniswap-gov/Timelock.sol';
import {GovernorBravoDelegate} from 'uniswap-gov/GovernorBravoDelegate.sol';
import {GovernorBravoDelegator} from 'uniswap-gov/GovernorBravoDelegator.sol';

// To run:
// forge script DeployGovernanceWithBravoScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify -vv --skip test
// to broadcast, add --broadcast flag


contract DeployGovernanceWithBravoScript is Script {

    address public publicKey = vm.envAddress("PUBLIC_KEY");
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    function priorVotesHelper(Uni uni, address user) public view {
        uint256 votes = uni.getPriorVotes(user, block.number - 1);
        console.log("address", user);
        console.log("prior votes", votes);
        uint256 numCheckPoints = uni.numCheckpoints(user);
        console.log("num checkpoints", numCheckPoints);
        for (uint32 i = 0; i < numCheckPoints; i++) {
            (uint32 fromBlock, uint96 votes) = uni.checkpoints(user, i);
            console.log("from block", fromBlock);
            console.log("votes", votes);
        }
    }

    function initialSetup() external {

        vm.startBroadcast(this.privateKey());
        console.log("block timestamp: ", block.timestamp);
        // 1. deploy uni token
        // vm.broadcast();
        Uni uni = new Uni(this.publicKey(), this.publicKey(), block.timestamp);
        console.log("Uni deployed at: ", address(uni));

        // 2. deploy timelock
        // vm.broadcast();
        Timelock timelock = new Timelock(this.publicKey(), 0);
        console.log("Timelock deployed at: ", address(timelock));
        
        // 3. deploy delegate
        // vm.broadcast();
        GovernorBravoDelegate delegate = new GovernorBravoDelegate();
        console.log("Delegate deployed at: ", address(delegate));

        // 4. deploy delegator    
        // vm.broadcast();        
        GovernorBravoDelegator delegator = new GovernorBravoDelegator(
            address(timelock),
            address(uni),
            this.publicKey(),  // admin
            address(delegate),
            50, // votingPeriod
            1, // votingDelay
            1e18); // proposalThreshold
        console.log("Delegator deployed at: ", address(delegator));        

        GovernorBravoDelegate delegateInterface = GovernorBravoDelegate(address(delegator));

        // 5. initiate GovernorBravo
        delegateInterface._initiate(1);
        console.log("GovernorBravo initiated");

        vm.stopBroadcast();

        this.tokenActions(uni);

    }

    function tokenActions(Uni uni) public {

        // 6. transfer uni to other accounts
        vm.startBroadcast(this.privateKey());
        uni.delegate(vm.envAddress("USER1_ADDRESS"));
        uni.transferFrom(this.publicKey(), vm.envAddress("USER1_ADDRESS"), 10_000_000_000_000_000_000);
        uni.transferFrom(this.publicKey(), vm.envAddress("USER2_ADDRESS"), 20_000_000_000_000_000_000);
        
        // 7. delegate UNI from those accounts to each other
        uni.delegate(vm.envAddress("USER2_ADDRESS"));
        vm.stopBroadcast();

        vm.startBroadcast(vm.envUint("USER1_PRIVATE_KEY"));
        // uni.delegate(vm.envAddress("USER1_ADDRESS"));
        uni.transferFrom(vm.envAddress("USER1_ADDRESS"), vm.envAddress("USER2_ADDRESS"), 1_000_000_000_000_000_000);
        uni.delegate(vm.envAddress("USER2_ADDRESS"));
        vm.stopBroadcast();
    }

    function createProposal(GovernorBravoDelegate delegateInterface, uint256 pk) public {        

        // 8. submit a proposal
        address[] memory addr = new address[](1);
        addr[0] = 0xbc3A7D78d2f4E4c22CA750a348a4ac93f5E4D188;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        string[] memory signatures = new string[](1);
        signatures[0] = "transfer(address,uint256)";

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(address(0xbc3A7D78d2f4E4c22CA750a348a4ac93f5E4D188), 1);

        vm.startBroadcast(pk);
        uint proposalId = delegateInterface.propose(
            addr, // test address
            values,
            signatures,
            calldatas, // will fail
            "transfer"
        );
        vm.stopBroadcast();
        console.log("Proposal id: ", proposalId);
    }

    function castVote(GovernorBravoDelegate delegateInterface, uint proposalId, uint8 support) public {
        vm.startBroadcast(vm.envUint("USER1_PRIVATE_KEY"));
        delegateInterface.castVote(proposalId, support);
        vm.stopBroadcast();
    }

    function deployUNI() public {
        vm.startBroadcast(this.privateKey());
        Uni uni = new Uni(this.publicKey(), this.publicKey(), block.timestamp);
        console.log("Uni deployed at: ", address(uni));
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

    function getUNIBalances(Uni uni) public {
        console.log("admin balance", uni.balanceOf(this.publicKey()));
        console.log("User1 balance: ", uni.balanceOf(vm.envAddress("USER1_ADDRESS")));
        console.log("User2 balance: ", uni.balanceOf(vm.envAddress("USER2_ADDRESS")));
    }

    function run() external {

        // first run
        // this.initialSetup();

        // second run
        Uni uni = Uni(address(0x7A443140508d25d66c367197Da2Da1844E1d8BCC));
        tokenActions(uni);
        
        // getUNIBalances(uni);
        // third run
        // GovernorBravoDelegate delegateInterface = GovernorBravoDelegate(address(0x19DF248A8443D057a9209142755e069403964546));
        priorVotesHelper(uni, this.publicKey());
        priorVotesHelper(uni, vm.envAddress("USER1_ADDRESS"));

        //this.createProposal(delegateInterface, vm.envUint("USER1_PRIVATE_KEY"));
        // this.createProposal(delegateInterface, this.privateKey());


        // fourth run
        // this.castVote(delegateInterface, 1, 2);
    }
}