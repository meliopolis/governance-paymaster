// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC20Test} from "../test/ERC20Test.sol";
import {TimelockController} from "@openzeppelin/contracts/governance/TimelockController.sol";
import {OZGovernor} from "../test/OZGovernor.sol";

// To run:
// forge script DeployOZGovernorWithTokenScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify -vv --skip test
// to broadcast, add --broadcast flag

contract DeployOZGovernorWithTokenScript is Script {
    address public publicKey = vm.envAddress("PUBLIC_KEY");
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    function initialSetup() external {
        vm.startBroadcast(this.privateKey());

        // 1. deploy uni token
        ERC20Test erc20Token = new ERC20Test();
        console.log("ERC20 deployed at: ", address(erc20Token));

        // 2. deploy timelock
        address[] memory proposers = new address[](1);
        proposers[0] = this.publicKey();
        address[] memory executors = new address[](1);
        executors[0] = this.publicKey();
        TimelockController timelock = new TimelockController(0, proposers, executors, this.publicKey());
        console.log("Timelock deployed at: ", address(timelock));

        // 3. deploy governor
        OZGovernor governor = new OZGovernor(erc20Token, timelock);
        console.log("Governor deployed at: ", address(governor));

        vm.stopBroadcast();
    }

    function run() external {
        this.initialSetup();
    }

    // add this to be excluded from coverage report
    function test() public {}
}
