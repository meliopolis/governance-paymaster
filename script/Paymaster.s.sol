// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import {BasePaymaster} from "account-abstraction/core/BasePaymaster.sol";
import {IStakeManager} from "account-abstraction/interfaces/IStakeManager.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

abstract contract PaymasterScript is Script {
    /**
     * Getters
     */
    function getPrivateKey() external view returns (uint256) {
        return vm.envUint("PRIVATE_KEY");
    }

    function getPublicKey() external view returns (address) {
        return vm.envAddress("PUBLIC_KEY");
    }

    function getEntryPoint() external view returns (IEntryPoint) {
        return IEntryPoint(address(vm.envAddress("ENTRY_POINT")));
    }

    // Gets deposit info (including stake) from entry point
    function getDepositInfoFromEntryPoint(address deployedPMAddress)
        external
        view
        returns (IStakeManager.DepositInfo memory)
    {
        BasePaymaster pm = BasePaymaster(deployedPMAddress);
        IEntryPoint entryPoint = IEntryPoint(address(pm.entryPoint()));
        return entryPoint.getDepositInfo(deployedPMAddress);
    }

    /*
     * Paymaster operations
     */

    // add deposit on behalf of Paymaster at EntryPoint
    function addDeposit(address toAddress, uint256 amount) external {
        vm.startBroadcast(this.getPrivateKey());
        BasePaymaster pm = BasePaymaster(payable(toAddress));
        pm.deposit{value: amount}();
        vm.stopBroadcast();
    }

    // withdraw remaining deposit from EntryPoint
    function withdrawRemainingDeposit(address deployedPMAddress, address sendToAddress) external {
        vm.startBroadcast(this.getPrivateKey());
        IStakeManager.DepositInfo memory depositInfo = this.getDepositInfoFromEntryPoint(deployedPMAddress);
        BasePaymaster pm = BasePaymaster(deployedPMAddress);
        pm.withdrawTo(payable(sendToAddress), depositInfo.deposit);
        vm.stopBroadcast();
    }

    // withdraw specific amount of deposit from EntryPoint
    function withdrawDeposit(address deployedPMAddress, address sendToAddress, uint256 amount) external {
        vm.startBroadcast(this.getPrivateKey());
        BasePaymaster pm = BasePaymaster(deployedPMAddress);
        pm.withdrawTo(payable(sendToAddress), amount);
        vm.stopBroadcast();
    }

    // addStake to EntryPoint
    function addStake(address deployedPMAddress, uint256 amount, uint32 delaySec) external {
        vm.startBroadcast(this.getPrivateKey());
        BasePaymaster pm = BasePaymaster(payable(deployedPMAddress));
        pm.addStake{value: amount}(delaySec);
        vm.stopBroadcast();
    }

    // unlock stake at EntryPoint
    function unlockStake(address deployedPMAddress) external {
        vm.startBroadcast(this.getPrivateKey());
        BasePaymaster pm = BasePaymaster(payable(deployedPMAddress));
        pm.unlockStake();
        vm.stopBroadcast();
    }

    // withdraw stake from EntryPoint (needs to be run after unlockStake is called)
    function withdrawStake(address deployedAddress, address sendToAddress) external {
        vm.startBroadcast(this.getPrivateKey());
        BasePaymaster pm = BasePaymaster(payable(deployedAddress));
        pm.withdrawStake(payable(sendToAddress));
        vm.stopBroadcast();
    }

    // useful when there is no stake
    function abandonPaymaster(address deployedPMAddress, address sendToAddress) external {
        vm.startBroadcast(this.getPrivateKey());
        BasePaymaster pm = BasePaymaster(payable(deployedPMAddress));
        IStakeManager.DepositInfo memory depositInfo = this.getDepositInfoFromEntryPoint(deployedPMAddress);
        require(depositInfo.stake == 0, "Need to use two step abandonment");
        pm.withdrawTo(payable(sendToAddress), depositInfo.deposit);
        vm.stopBroadcast();
    }

    // when there is a stake, call this first to unstake
    function abandonPaymasterStep1of2(address deployedPMAddress) external {
        vm.startBroadcast(this.getPrivateKey());
        BasePaymaster pm = BasePaymaster(payable(deployedPMAddress));
        pm.unlockStake();
        vm.stopBroadcast();
    }

    // call this next to withdraw stake and deposit
    function abandonPaymasterStep2of2(address deployedPMAddress, address sendToAddress) external {
        vm.startBroadcast(this.getPrivateKey());
        BasePaymaster pm = BasePaymaster(payable(deployedPMAddress));
        IStakeManager.DepositInfo memory depositInfo = this.getDepositInfoFromEntryPoint(deployedPMAddress);
        pm.withdrawTo(payable(sendToAddress), depositInfo.deposit);
        pm.withdrawStake(payable(sendToAddress));
        vm.stopBroadcast();
    }
}
