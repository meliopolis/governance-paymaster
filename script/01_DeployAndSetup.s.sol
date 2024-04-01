// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PaymasterDelegateERC20} from "../src/PaymasterDelegateERC20.sol";
import {PaymasterCastVote} from "../src/PaymasterCastVote.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";

// To run:
// forge script DeployAndSetupScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --verify -vv --skip test
// to broadcast, add --broadcast flag

contract DeployAndSetupScript is Script {

    function run() external {
        address erc20TokenAddress = vm.envAddress("ERC20_TOKEN");
        address governorBravoAddress = vm.envAddress("GOVERNOR_BRAVO");
        IEntryPoint entryPoint = IEntryPoint(vm.envAddress("ENTRY_POINT"));
        vm.startBroadcast();

        // Note: uncomment the appropriate line to deploy the desired paymaster
        // PaymasterDelegateERC20 paymaster = new PaymasterDelegateERC20(entryPoint, erc20TokenAddress);
        PaymasterCastVote paymaster = new PaymasterCastVote(entryPoint, erc20TokenAddress, governorBravoAddress);
        
        paymaster.deposit{value: 500_000_000_000_000_000}();
        // Note that 1 second is the minimum stake delay is too small for any mainnet deployment
        paymaster.addStake{value: 100_000_000_000_000_000}(1);
        vm.stopBroadcast();
        console.log("Paymaster deployed at: ", address(paymaster));
    }

    // add this to be excluded from coverage report
    function test() public {}
}
