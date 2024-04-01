// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// solhint-disable no-console
// solhint-disable custom-errors

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IStakeManager} from "account-abstraction/interfaces/IStakeManager.sol";
import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

// Note: Make sure you updated DEPOSIT_AMOUNT in the .env file

// To run:
// forge script IncreaseDepositScript --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY --skip test
// to broadcast, add --broadcast flag

/* 
 * This script increases the deposit amount for a user.
 */
contract IncreaseDepositScript is Script {
    function run() external {
        address paymasterAddress = vm.envAddress("PAYMASTER");
        uint256 depositAmount = vm.envUint("DEPOSIT_AMOUNT");

        // make sure Paymaster address exists
        require(paymasterAddress != address(0), "PAYMASTER not set");
        BasePaymaster pm = BasePaymaster(payable(paymasterAddress));

        // get deposit and stake info
        vm.startBroadcast();
        pm.deposit{value: depositAmount}();
        vm.stopBroadcast();
    }
    // add this to be excluded from coverage report

    function test() public {}
}
