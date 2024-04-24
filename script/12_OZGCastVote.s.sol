// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {Governor} from "@openzeppelin/contracts/governance/Governor.sol";
import {IGovernor} from "@openzeppelin/contracts/governance/IGovernor.sol";

// To run:
// forge script OZGCastVoteScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY -vv --skip test
// to broadcast, add --broadcast flag

contract OZGCastVoteScript is Script {
    address public publicKey = vm.envAddress("PUBLIC_KEY");
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    function castVote(Governor governor, uint256 proposalId, uint8 support) public {
        vm.startBroadcast(vm.envUint("USER1_PRIVATE_KEY"));
        governor.castVote(proposalId, support);
        vm.stopBroadcast();
    }

    function run() external {
        Governor governor = Governor(payable(vm.envAddress("GOVERNOR_BRAVO")));
        uint256 proposalId = 3819231313046571251926584140597625408036861828429919003987713890833504663719;
        IGovernor.ProposalState ps = governor.state(proposalId);
        console.logUint(uint256(ps));
        this.castVote(governor, proposalId, 2);
    }

    // add this to be excluded from coverage report
    function test() public {}
}
