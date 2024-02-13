// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "../src/PaymasterDelegateERC20.sol";
/**
 * Test Harness for PaymasterDelegateERC20 to test `internal` functions
 */

contract PaymasterDelegateERC20Harness is PaymasterDelegateERC20 {
    constructor(IEntryPoint entryPoint, address ERC20Address) PaymasterDelegateERC20(entryPoint, ERC20Address) {}

    function exposed_verifyERC20Holdings(address user) public view {
        return super._verifyERC20Holdings(user);
    }

    function exposed_verifyCallDataForDelegateAction(bytes calldata callData) public view {
        return super._verifyCallDataForDelegateAction(callData);
    }

    function exposed_validaterPaymasterUserOp(UserOperation calldata userOp, uint256 maxCost)
        public
        view
        returns (bytes memory, uint256)
    {
        return super._validatePaymasterUserOp(userOp, 0x0, maxCost);
    }

    function exposed_postOp(PostOpMode mode, bytes calldata context) public {
        return super._postOp(mode, context, 0);
    }
}
