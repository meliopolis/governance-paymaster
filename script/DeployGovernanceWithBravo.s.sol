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

    function initialSetup(address user1Address, address user2Address) external {
        vm.startBroadcast(this.privateKey());
        console.log("block timestamp: ", block.timestamp);
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
            5000, // votingPeriod in blocks
            1, // votingDelay
            1e18
        ); // proposalThreshold
        console.log("Delegator deployed at: ", address(delegator));

        GovernorBravoDelegate delegateInterface = GovernorBravoDelegate(address(delegator));

        // 5. initiate GovernorBravo
        delegateInterface._initiate(1);
        console.log("GovernorBravo initiated");

        vm.stopBroadcast();

        this.tokenActions(uni, user1Address, user2Address);
    }

    function tokenActions(Uni uni, address user1Address, address user2Address) public {
        // 6. transfer uni to other accounts
        vm.startBroadcast(this.privateKey());
        uni.delegate(user1Address);
        uni.transferFrom(this.publicKey(), user1Address, 10_000_000_000_000_000_000);
        uni.transferFrom(this.publicKey(), user2Address, 20_000_000_000_000_000_000);

        // 7. delegate UNI from those accounts to each other
        uni.delegate(user2Address);
        vm.stopBroadcast();

        // vm.startBroadcast(vm.envUint("USER1_PRIVATE_KEY"));
        // // uni.delegate(vm.envAddress("USER1_ADDRESS"));
        // uni.transferFrom(vm.envAddress("USER1_ADDRESS"), vm.envAddress("USER2_ADDRESS"), 1_000_000_000_000_000_000);
        // uni.delegate(vm.envAddress("USER2_ADDRESS"));
        // vm.stopBroadcast();
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
        uint256 proposalId = delegateInterface.propose(
            addr, // test address
            values,
            signatures,
            calldatas, // will fail
            "transfer"
        );
        vm.stopBroadcast();
        console.log("Proposal id: ", proposalId);
    }

    function castVote(GovernorBravoDelegate delegateInterface, uint256 proposalId, uint8 support) public {
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
        address user1AddressEOA = vm.envAddress("USER1_ADDRESS"); // used for local fork
        address user1AddressAA = 0xb979c4469eE958518497F657103b120C95bE2795; // update to test on sepolia
        address user2Address = vm.envAddress("USER2_ADDRESS");

        this.initialSetup(user1AddressAA, user2Address);

        // update after first run
        // address delegateAddress = 0x6DFDC91b9B189B7DeB98e19502aee298E77D49dc;
        // address uniAddress = 0x4ACd80BAF226eF119ceaC073EF85D6BF01c639cF;

        // second run
        // GovernorBravoDelegate delegateInterface = GovernorBravoDelegate(delegateAddress);
        // this.createProposal(delegateInterface, this.privateKey()); // changing from USER1_PRIVATE_KEY

        // third run; need to move the clock forward;
        // GovernorBravoDelegate delegateInterface = GovernorBravoDelegate(delegateAddress);
        // // this.createProposal(delegateInterface, this.privateKey());
        // Uni uni = Uni(uniAddress);
        // tokenActions(uni);

        // fourth run
        // GovernorBravoDelegate delegateInterface = GovernorBravoDelegate(delegateAddress);
        // this.castVote(delegateInterface, 3, 2);
    }

    // add this to be excluded from coverage report
    function test() public {}
}
