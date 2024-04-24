// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OZGovernor} from "../test/OZGovernor.sol";
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
// To run:
// forge script CreateOZBProposalScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY -vv --skip test
// to broadcast, add --broadcast flag

contract CreateOZBProposalScript is Script {
    address public publicKey = vm.envAddress("PUBLIC_KEY");
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    function createProposal(Governor governor, uint256 pk) public {
        // 8. submit a proposal

        /*

                address[] memory targets,
        uint256[] memory values,
        bytes[] memory calldatas,
        string memory description

        */
        address[] memory targets = new address[](1);
        targets[0] = 0xbc3A7D78d2f4E4c22CA750a348a4ac93f5E4D188;

        uint256[] memory values = new uint256[](1);
        values[0] = 0;

        bytes[] memory calldatas = new bytes[](1);
        calldatas[0] = abi.encode(address(0xbc3A7D78d2f4E4c22CA750a348a4ac93f5E4D188), 1);

        vm.startBroadcast(pk);
        uint256 proposalId = governor.propose(
            targets, // test address
            values,
            calldatas, // will fail
            "transfer"
        );
        vm.stopBroadcast();
        console.log("Proposal id: ", proposalId);
    }

    function run() external {
        Governor governor = Governor(payable(vm.envAddress("GOVERNOR_BRAVO")));
        this.createProposal(governor, this.privateKey()); // changing from USER1_PRIVATE_KEY
    }

    // add this to be excluded from coverage report
    function test() public {}
}
