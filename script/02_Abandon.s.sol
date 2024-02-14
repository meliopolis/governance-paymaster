// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

// solhint-disable no-console 
// solhint-disable custom-errors

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {IStakeManager} from "account-abstraction/interfaces/IStakeManager.sol";
import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

// To run:
// forge script AbandonScript --rpc-url $SEPOLIA_RPC_URL --broadcast --via-ir --skip test
// Note: this may need to be run multiple times to fully abandon a paymaster.
// First run will unlock stake if needed and second run will withdraw deposit and stake.

contract AbandonScript is Script {
    function run() external {
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        address publicKey = vm.envAddress("PUBLIC_KEY");
        address paymasterAddress = vm.envAddress("PAYMASTER");
        
        // make sure Paymaster address exists
        require(paymasterAddress != address(0), "PAYMASTER not set");
        BasePaymaster pm = BasePaymaster(payable(paymasterAddress));
        IEntryPoint entryPoint = IEntryPoint(vm.envAddress("ENTRY_POINT"));
        
        // get deposit and stake info
        IStakeManager.DepositInfo memory depositInfo = entryPoint.getDepositInfo(paymasterAddress);
        vm.startBroadcast(privateKey);
        
        // case 1: no stake
        if (depositInfo.stake == 0) {
            // check to make sure there is something to withdraw (in case already abandoned)
            require(depositInfo.deposit > 0, "No deposit to withdraw");

            // withdraw deposit and done
            pm.withdrawTo(payable(publicKey), depositInfo.deposit);
            console.log("No stake, withdrawing deposit. All Done.");
            return;
        }
        // case 2: stake exists and is locked
        else if (depositInfo.staked == true) {
            // unlock stake
            pm.unlockStake();
            IStakeManager.DepositInfo memory updatedDepositInfo = entryPoint.getDepositInfo(paymasterAddress);
            console.log(
                "Stake unlocked, need to run again in ", updatedDepositInfo.withdrawTime - block.timestamp, " seconds"
            );
            return;
        }
        // case 3: stake exists, is unlocked and withdrawTime in the past
        else if (depositInfo.withdrawTime < block.timestamp) {
            pm.withdrawTo(payable(publicKey), depositInfo.deposit);
            pm.withdrawStake(payable(publicKey));
            console.log("Deposit and stake withdrawn: ", depositInfo.deposit, depositInfo.stake);
        }
        // case 4: stake exists, is unlocked but withdrawTime in the future
        else {
            revert("withdrawTime in the future");
        }
        vm.stopBroadcast();
    }
}
