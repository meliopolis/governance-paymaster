// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BasePaymaster} from "@account-abstraction/core/BasePaymaster.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "@account-abstraction/interfaces/UserOperation.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {_packValidationData} from "@account-abstraction/core/Helpers.sol";
import {Uni} from "uniswap-gov/Uni.sol";

// Custom errors, as they are more gas efficient than strings
error IncorrectCallDataLengthOf228Bytes();
error IncorrectExecuteSignature();
error InvalidGovernorBravoAddress();
error ValueMustBeZero();
error Data1MustBe0x60();
error Data2MustBe0x44();
error IncorrectCastVoteSignature();
error SupportMustBeLessThanOrEqualToTwo();
error SenderOnBlocklist();
error MaxCostExceedsAllowedAmount(uint256 maxCost);

/**
 * This paymaster pays for gas when a user casts a vote on a GovernorBravo Contract
 */
contract PaymasterCastVote is BasePaymaster, Pausable {
    // max ETH, in Wei, that the paymaster is willing to pay for the operation
    // This shouldn't need to be higher than say 0.01 ETH.
    // but it needs to also cover initial deployment in some cases, so it's set to a higher amount.
    uint256 private _maxCostAllowed = 300_000_000_000_000_000; // 0.3 ETH
    address private _erc20Address;
    address private _governorBravoAddress;

    // blocklist - tracks any address whose transaction reverts
    mapping(address => bool) public blocklist;

    constructor(IEntryPoint entryPoint, address erc20Address, address governorBravoAddress) BasePaymaster(entryPoint) Ownable(msg.sender) {
        // solhint-disable avoid-tx-origin
        if (tx.origin != msg.sender) {
            _transferOwnership(tx.origin);
        }
        _erc20Address = erc20Address;
        _governorBravoAddress = governorBravoAddress;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    /* HELPERS for Paymaster state */
    function getMaxCostAllowed() public view returns (uint256) {
        return _maxCostAllowed;
    }

    function updateMaxCostAllowed(uint256 maxCost) public onlyOwner {
        _maxCostAllowed = maxCost;
    }

    function getGovernorBravoAddress() public view returns (address) {
        return _governorBravoAddress;
    }

    /**
     * Verifies that the callData is accurate for a castVote() Action
     * Ex: GovernorBravo castVote. Total 228 bytes
     * 0x
     * b61d27f6 "execute" hash
     * 000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3 "governorBravoAddress" for Uniswap on mainnet
     * 0000000000000000000000000000000000000000000000000000000000000000 value
     * 0000000000000000000000000000000000000000000000000000000000000060 data1
     * 0000000000000000000000000000000000000000000000000000000000000044 data2
     * 56781388 "castVote" hash
     * 0000000000000000000000000000000000000000000000000000000000000034 proposalId
     * 0000000000000000000000000000000000000000000000000000000000000001 support
     * 00000000000000000000000000000000000000000000000000000000 filler
     */
    function _verifyCallDataForCastVoteAction(bytes calldata callData) internal view {
        // check length
        if (callData.length != 228) revert IncorrectCallDataLengthOf228Bytes();

        // extract initial `execute` signature. Need to extract this separately because of the way abi.decode works
        bytes4 executeSig = bytes4(callData[:4]);
        if (executeSig != bytes4(keccak256("execute(address,uint256,bytes)"))) revert IncorrectExecuteSignature();

        // extract rest of info from callData
        (address toAddress, bytes32 value, bytes32 data1, bytes32 data2) =
            abi.decode(callData[4:132], (address, bytes32, bytes32, bytes32));
        bytes4 castVoteHash = bytes4(callData[132:136]);
        // extract proposalId and support
        // Note: there isn't much we can check with proposalId, since we can't access the storage from GovernorBravo
        (, uint256 support) = abi.decode(callData[136:200], (uint256, uint256));
        // note that there is additional 28 bytes of filler data at the end that we ignore

        // check each one
        if (toAddress != _governorBravoAddress) revert InvalidGovernorBravoAddress();
        if (value != 0) revert ValueMustBeZero();
        if (data1 != hex"0000000000000000000000000000000000000000000000000000000000000060") revert Data1MustBe0x60();
        if (data2 != hex"0000000000000000000000000000000000000000000000000000000000000044") revert Data2MustBe0x44();
        if (bytes4(castVoteHash) != bytes4(keccak256("castVote(uint256,uint8)"))) revert IncorrectCastVoteSignature();
        if (support > 2) revert SupportMustBeLessThanOrEqualToTwo();
    }

    /**
     * Validates the user operation when called by EntryPoint
     */
    function _validatePaymasterUserOp(UserOperation calldata userOp, bytes32, uint256 maxCost)
        internal
        view
        virtual
        override
        whenNotPaused
        returns (bytes memory context, uint256 validationData)
    {
        // check maxCost is less than _maxCostAllowed
        if (maxCost > _maxCostAllowed) revert MaxCostExceedsAllowedAmount(maxCost);

        // check if the user is in the blocklist
        if (blocklist[userOp.sender]) revert SenderOnBlocklist();

        // verify that calldata is accuarate.
        _verifyCallDataForCastVoteAction(userOp.callData);

        // verify that sender has some ERC20 token delegated to them
        // TODO: don't have startBlock info. Either need to include that manually or skip this part
        // uint96 delegatedTokenAmount = getPriorVotes(userOp.sender, _proposals[proposalId].startBlock);

        return (abi.encode(userOp.sender), _packValidationData(false, 0, 0));
    }

    /*
     * Called after the operation has been executed
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256) internal override {
        // 1. opSucceeded: do nothing
        // 2. opReverted: record caller address in a blocklist
        // This is to prevent the same address from calling the paymaster again
        if (mode == PostOpMode.opReverted) {
            (address caller) = abi.decode(context, (address));
            blocklist[caller] = true;
        }
        // 3. postOpReverted: not applicable. Based on current implementation, this should never happen
    }
}
