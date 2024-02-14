// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {PaymasterDelegateERC20} from "../src/PaymasterDelegateERC20.sol";
import {IEntryPoint} from "account-abstraction/interfaces/IEntryPoint.sol";

// To run:
// forge script DeployAndSetupScript --rpc-url $SEPOLIA_RPC_URL --broadcast --etherscan-api-key $ETHERSCAN_API_KEY --verify -vv --skip test --via-ir
contract DeployAndSetupScript is Script {
    function run() external {
        address erc20TokenAddress = vm.envAddress("ERC20_TOKEN");
        uint256 privateKey = vm.envUint("PRIVATE_KEY");
        IEntryPoint entryPoint = IEntryPoint(address(vm.envAddress("ENTRY_POINT"))); // h.getEntryPoint();
        vm.startBroadcast(privateKey);
        PaymasterDelegateERC20 paymaster = new PaymasterDelegateERC20(entryPoint, erc20TokenAddress);
        paymaster.deposit{value: 500_000_000_000_000_000}();
        // Note that 1 second is the minimum stake delay is too small for any mainnet deployment
        paymaster.addStake{value: 100_000_000_000_000_000}(1);
        vm.stopBroadcast();
        console.log("Paymaster deployed at: ", address(paymaster));
    }
}
