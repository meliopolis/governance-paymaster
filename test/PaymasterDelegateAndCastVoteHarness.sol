// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "../src/PaymasterDelegateAndCastVote.sol";
/**
 * Test Harness for PaymasterCastVote to test `internal` functions
 */

contract PaymasterDelegateAndCastVoteHarness is PaymasterDelegateAndCastVote {
    constructor(IEntryPoint entryPoint, address ERC20Address, address governorBravoAddress)
        PaymasterDelegateAndCastVote(entryPoint, ERC20Address, governorBravoAddress)
    {}

    function exposed_verifyERC20Holdings(address user) public view {
        return super._verifyERC20Holdings(user);
    }

    function exposed_verifyCallDataForCastVoteAction(bytes calldata callData) public view {
        return super._verifyCallDataForCastVoteAction(callData);
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
