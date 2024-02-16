// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// solhint-disable no-console 
// solhint-disable custom-errors

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PaymasterDelegateERC20} from "../src/PaymasterDelegateERC20.sol";

// Note: Make sure you updated MAX_COST_ALLOWED in the .env file

// To run:
// forge script UpdateMaxCostAllowedScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --skip test
// to broadcast, add --broadcast flag

/* 
 * This script updates the max cost allowed by the paymaster.
 */
contract UpdateMaxCostAllowedScript is Script {
    function run() external {
        address paymasterAddress = vm.envAddress("PAYMASTER");
        uint256 newMaxCostAllowed = vm.envUint("MAX_COST_ALLOWED");
        
        // make sure Paymaster address exists
        require(paymasterAddress != address(0), "PAYMASTER not set");
        PaymasterDelegateERC20 pm = PaymasterDelegateERC20(payable(paymasterAddress));
        
        uint256 currentMaxCost = pm.getMaxCostAllowed();
        if (currentMaxCost == newMaxCostAllowed) {
            console.log("Max cost already set to", newMaxCostAllowed);
            return;
        }
        // get deposit and stake info
        vm.startBroadcast();
        pm.updateMaxCostAllowed(newMaxCostAllowed);
        vm.stopBroadcast();
    }
}
