// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BasePaymaster} from "@account-abstraction/core/BasePaymaster.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "@account-abstraction/interfaces/UserOperation.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import {_packValidationData} from "@account-abstraction/core/Helpers.sol";

// Custom errors, as they are more gas efficient than strings
error MinDayMustBeGreaterThan1Day();
error IncorrectCallDataLengthOf196OR228Bytes();
error IncorrectExecuteSignature();
error InvalidERC20Address();
error InvalidGovernorBravoAddress();
error ValueMustBeZero();
error Data1MustBe0x60();
error Data2ForDelegateMustBe0x24();
error Data2ForCastVoteMustBe0x44();
error IncorrectDelegateSignature();
error IncorrectCastVoteSignature();
error DelegateeCannotBe0x0();
error SupportMustBeLessThanOrEqualToTwo();
error SenderOnBlocklist();
error MaxCostExceedsAllowedAmount(uint256 maxCost);
error SenderDoesNotHoldAnyERC20Tokens();

/**
 * This paymaster pays for gas when a user delgates or casts a vote.
 * The paymaster checks to make sure the user holds non-zero amount of ERC20 tokens before paying for gas.
 * It also keeps track of the last time a user delegated their vote, and enforces a minimum wait time between delegations.
 */
contract PaymasterDelegateAndCastVote is BasePaymaster, Pausable {
    // max ETH, in Wei, that the paymaster is willing to pay for the operation
    // This shouldn't need to be higher than say 0.01 ETH.
    // but it needs to also cover initial deployment in some cases, so it's set to a higher amount.
    uint256 private _maxCostAllowed = 300_000_000_000_000_000; // 0.3 ETH
    uint256 private _minWaitBetweenDelegations = 90 days;
    address private _erc20Address;
    address private _governorBravoAddress;

    enum Action {
        DELEGATE,
        CAST_VOTE
    }

    // blocklist - tracks any address whose transaction reverts
    mapping(address => bool) public blocklist;

    // Track the last known delegation happened from this account
    mapping(address => uint256) public lastDelegationTimestamp;

    constructor(IEntryPoint _entryPoint, address erc20Address, address governorBravoAddress)
        BasePaymaster(_entryPoint)
        Ownable(msg.sender)
    {
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

    function getMinWaitBetweenDelegations() public view returns (uint256) {
        return _minWaitBetweenDelegations;
    }

    function updateMinWaitBetweenDelegations(uint256 minWait) public onlyOwner {
        if (minWait < 1 days) revert MinDayMustBeGreaterThan1Day();
        _minWaitBetweenDelegations = minWait;
    }

    function getERC20Address() public view returns (address) {
        return _erc20Address;
    }

    function getGovernorBravoAddress() public view returns (address) {
        return _governorBravoAddress;
    }

    /**
     * Verifies that the callData is accurate for a delegate action
     * Ex: ERC20 Delegate call. Total 196 bytes
     *  0x
     *  b61d27f6 "execute" hash
     *  0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984 ex: ERC20 address
     *  0000000000000000000000000000000000000000000000000000000000000000 value
     *  0000000000000000000000000000000000000000000000000000000000000060 data1
     *  0000000000000000000000000000000000000000000000000000000000000024 data2
     *  5c19a95c "delegate" hash
     *  000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676 delegatee
     *  00000000000000000000000000000000000000000000000000000000 filler
     *
     * OR
     *
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
    function _verifyCallDataForDelegateAction(bytes calldata callData) internal view {
        // extract initial `execute` signature. Need to extract this separately because of the way abi.decode works
        bytes4 executeSig = bytes4(callData[:4]);
        if (executeSig != bytes4(keccak256("execute(address,uint256,bytes)"))) revert IncorrectExecuteSignature();

        // extract rest of info from callData
        (address toAddress, bytes32 value, bytes32 data1, bytes32 data2) =
            abi.decode(callData[4:132], (address, bytes32, bytes32, bytes32));
        bytes4 delegateHash = bytes4(callData[132:136]);
        address delegatee = abi.decode(callData[136:168], (address));
        // note that there is additional 28 bytes of filler data at the end that we ignore

        // check each one
        if (toAddress != _erc20Address) revert InvalidERC20Address();
        if (value != 0) revert ValueMustBeZero();
        if (data1 != hex"0000000000000000000000000000000000000000000000000000000000000060") revert Data1MustBe0x60();
        if (data2 != hex"0000000000000000000000000000000000000000000000000000000000000024") {
            revert Data2ForDelegateMustBe0x24();
        }
        if (bytes4(delegateHash) != bytes4(keccak256("delegate(address)"))) revert IncorrectDelegateSignature();
        if (delegatee == address(0)) revert DelegateeCannotBe0x0();
    }

    function _verifyCallDataForCastVoteAction(bytes calldata callData) internal view {
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
        if (data2 != hex"0000000000000000000000000000000000000000000000000000000000000044") {
            revert Data2ForCastVoteMustBe0x44();
        }
        if (bytes4(castVoteHash) != bytes4(keccak256("castVote(uint256,uint8)"))) revert IncorrectCastVoteSignature();
        if (support > 2) revert SupportMustBeLessThanOrEqualToTwo();
    }

    /**
     * Verifies that the sender holds ERC20 tokens
     * Note that this doesn't work when the token is accessed via a Proxy contract, due to storage access rules
     */
    function _verifyERC20Holdings(address sender) internal view {
        IERC20 token = IERC20(_erc20Address);
        uint256 tokenBalance = token.balanceOf(sender);
        if (tokenBalance == 0) revert SenderDoesNotHoldAnyERC20Tokens();
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

        // verify that sender holds ERC20 token
        _verifyERC20Holdings(userOp.sender);

        // set validAfter to 0, which means always valid
        uint256 validAfter = 0;
        // set validUntil to 0, which means no time limit on the transaction
        uint256 validUntil = 0;

        // verify calldata
        if (userOp.callData.length == 228) {
            _verifyCallDataForCastVoteAction(userOp.callData);
            return (
                abi.encode(userOp.sender, Action.CAST_VOTE),
                _packValidationData(false, uint48(validUntil), uint48(validAfter))
            );
        } else if (userOp.callData.length == 196) {
            _verifyCallDataForDelegateAction(userOp.callData);

            // calculate minTimestamp that the user can delegate again
            // since this function doesn't know block.timestamp, it sets the minimum valid time to be
            // lastDelegationTimestamp + _minWaitBetweenDelegations
            // if the user has never delegated before, then it sets validAfter to be in the past
            // if the user has delegated before, it will ensure validAfter is at least _minWaitBetweenDelegations after the last delegation
            validAfter = lastDelegationTimestamp[userOp.sender] + _minWaitBetweenDelegations;

            // set validUntil to 0, which means no time limit on the transaction
            validUntil = 0;

            // but if the user has delegated before, set validAfter to be 30 minutes from validAfter
            // this is an optimization, might not be necessary either.
            if (lastDelegationTimestamp[userOp.sender] > 0) {
                validUntil = validAfter + 30 minutes;
            }
            return (
                abi.encode(userOp.sender, Action.DELEGATE),
                _packValidationData(false, uint48(validUntil), uint48(validAfter))
            );
        } else {
            revert IncorrectCallDataLengthOf196OR228Bytes();
        }
    }

    /*
     * Called after the operation has been executed
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256) internal override {
        // 1. opSucceeded: record the last delegation timestamp
        if (mode == PostOpMode.opSucceeded) {
            (address caller, Action action) = abi.decode(context, (address, Action));
            if (action == Action.DELEGATE) {
                lastDelegationTimestamp[caller] = block.timestamp;
            }
        }
        // 2. opReverted: record caller address in a blocklist
        // This is to prevent the same address from calling the paymaster again
        else if (mode == PostOpMode.opReverted) {
            (address caller,) = abi.decode(context, (address, Action));
            blocklist[caller] = true;
        }
        // 3. postOpReverted: not applicable. Based on current implementation, this should never happen
    }
}
