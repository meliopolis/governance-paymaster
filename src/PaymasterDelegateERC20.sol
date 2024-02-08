// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {BasePaymaster} from "@account-abstraction/core/BasePaymaster.sol";
import {Pausable} from "@openzeppelin/utils/Pausable.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {UserOperation} from "@account-abstraction/interfaces/UserOperation.sol";
import {IERC20} from "@openzeppelin/interfaces/IERC20.sol";
import "@account-abstraction/core/Helpers.sol";
import "@openzeppelin/utils/Strings.sol";

/**
 * This paymaster pays for gas when a user delegates their vote to another address.
 * The paymaster checks to make sure the user holds non-zero amount of ERC20 tokens before paying for gas.
 * It also keeps track of the last time a user delegated their vote, and enforces a minimum wait time between delegations.
 */
contract PaymasterDelegateERC20 is BasePaymaster, Pausable {
    // max ETH, in Wei, that the paymaster is willing to pay for the operation
    // TODO: this shouldn't need to be higher than say 0.01 ETH.
    // but initial txn failing if not. Need to investigate
    uint256 private _maxCostAllowed = 300_000_000_000_000_000; // 0.3 ETH
    uint256 private _minWaitBetweenDelegations = 30 days;
    address private _erc20Address;

    // blocklist - tracks any address whose transaction reverts
    mapping(address => bool) public blocklist;

    // Track the last known delegation happened from this account
    mapping(address => uint256) public lastDelegationTimestamp;

    constructor(IEntryPoint _entryPoint, address ERC20Address) BasePaymaster(_entryPoint) Ownable(msg.sender) {
        // solhint-disable avoid-tx-origin
        if (tx.origin != msg.sender) {
            _transferOwnership(tx.origin);
        }
        _erc20Address = ERC20Address;
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
        require(minWait > 1 days, "minWait must be greater than 1 day");
        _minWaitBetweenDelegations = minWait;
    }

    function getERC20Address() public view returns (address) {
        return _erc20Address;
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
     *  000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676 delgatee
     *  00000000000000000000000000000000000000000000000000000000 filler
     */
    function _verifyCallDataForDelegateAction(bytes calldata callData) internal view {
        // check length
        require(callData.length == 196, "callData must be 196 bytes");

        // extract initial `execute` signature. Need to extract this separately because of the way abi.decode works
        bytes4 executeSig = bytes4(callData[:4]);
        require(executeSig == bytes4(keccak256("execute(address,uint256,bytes)")), "incorrect execute signature");

        // extract rest of info from callData
        (address toAddress, bytes32 value, bytes32 data1, bytes32 data2) =
            abi.decode(callData[4:132], (address, bytes32, bytes32, bytes32));
        bytes4 delegateHash = bytes4(callData[132:136]);
        address delegatee = abi.decode(callData[136:168], (address));
        // note that there is additional 28 bytes of filler data at the end

        // check each one
        require(toAddress == _erc20Address, "address needs to point to the ERC20 token address");
        require(value == 0, "value needs to be 0"); // no need to send any money to paymaster, nor can it accept any
        require(
            data1 == hex"0000000000000000000000000000000000000000000000000000000000000060", "data1 needs to be 0x60"
        );
        require(
            data2 == hex"0000000000000000000000000000000000000000000000000000000000000024", "data2 needs to be 0x24"
        );
        require(bytes4(delegateHash) == bytes4(keccak256("delegate(address)")), "incorrect delegate signature");
        require(delegatee != address(0), "delegatee cannot be 0x0");
    }

    /**
     * Verifies that the sender holds ERC20 tokens
     * Note that this doesn't work when the token is accessed via a Proxy contract, due to storage access rules
     */

    function _verifyERC20Holdings(address sender) internal view {
        IERC20 token = IERC20(_erc20Address);
        uint256 tokenBalance = token.balanceOf(sender);
        require(tokenBalance > 0, "sender does not hold any ERC20 Tokens");
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
        require(maxCost < _maxCostAllowed, string.concat(Strings.toString(maxCost), " maxCost exceeds allowed amount"));

        // check if the user is in the blocklist
        require(!blocklist[userOp.sender], "user is in the blocklist");

        // verify that calldata is accuarate.
        _verifyCallDataForDelegateAction(userOp.callData);

        // verify that sender holds ERC20 token
        _verifyERC20Holdings(userOp.sender);

        // calculate minTimestamp that the user can delegate again
        // since this function doesn't know block.timestamp, it sets the minimum valid time to be
        // lastDelegationTimestamp + _minWaitBetweenDelegations
        uint256 validAfter = lastDelegationTimestamp[userOp.sender] + _minWaitBetweenDelegations;

        // TODO: confirm if validAfter is 30 days away, does the Bundler holds it until then? Or does it
        // have an expiration?
        // TODO: should we set validUntil to be 30 mins after validAfter?
        return (abi.encode(userOp.sender), _packValidationData(false, uint48(0), uint48(validAfter)));
    }

    /*
     * Called after the operation has been executed
     */
    function _postOp(PostOpMode mode, bytes calldata context, uint256) internal override {
        // 1. opSucceeded: do nothing
        // Record the last delegation timestamp
        if (mode == PostOpMode.opSucceeded) {
            (address caller) = abi.decode(context, (address));
            lastDelegationTimestamp[caller] = block.timestamp;
        }
        // 2. opReverted: record caller address in a blocklist
        // This is to prevent the same address from calling the paymaster again
        else if (mode == PostOpMode.opReverted) {
            (address caller) = abi.decode(context, (address));
            blocklist[caller] = true;
        }
        // 3. postOpReverted: not applicable. Based on current implementation, this should never happen
    }
}
