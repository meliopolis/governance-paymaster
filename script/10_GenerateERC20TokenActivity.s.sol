// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;
// solhint-disable no-console

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {ERC20Test, ERC20} from "../test/ERC20Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// To run:
// forge script GenerateERC20TokenActivityPreVote --rpc-url $SEPOLIA_RPC_URL --private-key $PRIVATE_KEY -vv --skip test
// to broadcast, add --broadcast flag

contract GenerateERC20TokenActivityPreVote is Script {
    address public publicKey = vm.envAddress("PUBLIC_KEY");
    uint256 public privateKey = vm.envUint("PRIVATE_KEY");

    function tokenActions(ERC20Test erc20, address user1Address, address user2Address) public {
        // 1. transfer uni to other accounts
        vm.startBroadcast(this.privateKey());
        erc20.delegate(user1Address);
        erc20.transfer(user1Address, 10_000_000_000_000_000_000);
        erc20.transfer(user2Address, 20_000_000_000_000_000_000);

        // 2. delegate UNI from those accounts to each other
        erc20.delegate(user2Address);
        vm.stopBroadcast();
    }

    function run() external {
        // address user1Address = vm.envAddress("USER1_ADDRESS"); // EOA for local fork
        address user1Address = vm.envAddress("AA_ADDRESS"); // AA Wallet
        address user2Address = vm.envAddress("USER2_ADDRESS");

        ERC20Test erc20Token = ERC20Test(vm.envAddress("ERC20_TOKEN"));
        this.tokenActions(erc20Token, user1Address, user2Address);
    }

    // add this to be excluded from coverage report
    function test() public {}
}
