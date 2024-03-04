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
// forge script CreateProposalScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify -vv --skip test
// to broadcast, add --broadcast flag

contract CreateProposalScript is Script {
    address public publicKey = vm.envAddress("PUBLIC_KEY");
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

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

    function run() external {
        
        GovernorBravoDelegate delegateInterface = GovernorBravoDelegate(vm.envAddress("GOVERNOR_BRAVO"));
        this.createProposal(delegateInterface, this.privateKey()); // changing from USER1_PRIVATE_KEY
    }

    // add this to be excluded from coverage report
    function test() public {}
}
