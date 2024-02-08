// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Script.sol";
import "./Paymaster.s.sol";
import "../src/PaymasterDelegateERC20.sol";

// To run:
// forge script PaymasterDelegateERC20Script --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vvvv
contract PaymasterDelegateERC20Script is PaymasterScript {
    function updateMaxCostAllowed(address deployedPMAddress, uint256 newMaxCost) external {
        vm.startBroadcast(this.getPrivateKey());
        BasePaymaster pm = BasePaymaster(deployedPMAddress);
        PaymasterDelegateERC20 pmDelegate = PaymasterDelegateERC20(address(pm));
        pmDelegate.updateMaxCostAllowed(newMaxCost);
        vm.stopBroadcast();
    }

    function deploy(address erc20Address) external returns (address) {
        vm.startBroadcast(this.getPrivateKey());
        IEntryPoint entryPoint = this.getEntryPoint();
        BasePaymaster paymaster = new PaymasterDelegateERC20(entryPoint, erc20Address);
        address paymasterAddress = address(paymaster);
        vm.stopBroadcast();
        return paymasterAddress;
    }

    function deployAndSetupNewPaymaster(address erc20Token, uint256 deposit, uint256 stake, uint32 stakeDelaySec)
        external
    {
        // deploy
        address deployedAddress = this.deploy(erc20Token);
        // add deposit
        this.addDeposit(deployedAddress, deposit);
        // add stake
        this.addStake(deployedAddress, stake, stakeDelaySec);
    }

    function run() external {
        /* to deploy */
        //address ERC20Token = vm.envAddress("ERC20_TOKEN");
        // this.deployAndSetupNewPaymaster(ERC20Token, 500_000_000_000_000_000, 100_000_000_000_000_000, 1);

        /* to withdraw (2 steps)
            Step 0: update address of paymaster
            Step 1: uncomment next two lines and run
        */
        address deployedAddress = address(0x61eEaccfd276F90F279b3f175ab6AA06374C389C);
        this.updateMaxCostAllowed(deployedAddress, 400_000_000_000_000_000);
        // this.abandonPaymasterStep1of2(deployedAddress);
        // this.abandonPaymasterStep2of2(deployedAddress, this.getPublicKey());
    }
}
