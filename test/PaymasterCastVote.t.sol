// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {UserOperation} from "@account-abstraction/interfaces/UserOperation.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {IPaymaster} from "@account-abstraction/interfaces/IPaymaster.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC20Test} from "./ERC20Test.sol";
import {PaymasterCastVoteHarness} from "./PaymasterCastVoteHarness.sol";
// solhint-disable-next-line no-global-import
import "../src/PaymasterCastVote.sol";

// solhint-disable func-name-mixedcase
// solhint-disable custom-errors

contract PaymasterCastVoteTest is Test {
    PaymasterCastVote public paymaster;
    PaymasterCastVoteHarness public paymasterHarness;
    ERC20Test public erc20;
    address governorBravoAddress = 0x408ED6354d4973f66138C91495F2f2FCbd8724C3;
    address public owner = vm.envAddress("PUBLIC_KEY");
    address public entryPointAddress = vm.envAddress("ENTRY_POINT");
    address public alice = address(0x1);

    bytes public correctCallData;

    /**
     * Ex: GovernorBravo castVote. Total 228 bytes
     * 0x
     * b61d27f6 "execute" hash
     * 000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3 "governorBravoAddress"
     * 0000000000000000000000000000000000000000000000000000000000000000 value
     * 0000000000000000000000000000000000000000000000000000000000000060 data1
     * 0000000000000000000000000000000000000000000000000000000000000044 data2
     * 56781388 "castVote" hash
     * 0000000000000000000000000000000000000000000000000000000000000034 proposalId
     * 0000000000000000000000000000000000000000000000000000000000000001 support
     * 00000000000000000000000000000000000000000000000000000000 filler
     */

    /*
     * Setup
     */
    function setUp() public {
        IEntryPoint entryPoint = IEntryPoint(entryPointAddress);
        vm.startPrank(owner, owner);
        erc20 = new ERC20Test();
        paymaster = new PaymasterCastVote(entryPoint, address(erc20), governorBravoAddress);
        paymasterHarness = new PaymasterCastVoteHarness(entryPoint, address(erc20), governorBravoAddress);
        correctCallData = bytes.concat(
            hex"b61d27f6", // execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3", // governorBravoAddress
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"56781388" // "castVote" signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId
            hex"0000000000000000000000000000000000000000000000000000000000000001" // support
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.stopPrank();
    }

    /*
     * Helpers
     */
    function _userOpsHelper(bytes memory callData, address sender) internal pure returns (UserOperation memory) {
        UserOperation memory userOp = UserOperation(address(sender), 0, hex"", callData, 0, 0, 0, 0, 0, hex"", hex"");
        return userOp;
    }

    /*
     * Deploy
     */
    function test_Deploy() public {
        assertEq(paymaster.owner(), owner);
        assertEq(address(paymaster.entryPoint()), entryPointAddress);
        assertEq(paymaster.getERC20Address(), address(erc20));
        assertEq(paymaster.getGovernorBravoAddress(), governorBravoAddress);
    }

    /*
     * Setters and pause/unpause
     */
    function test_pauseNotAsOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        paymaster.pause();
    }

    function test_unpauseNotAsOwner() public {
        vm.prank(owner);
        paymaster.pause();
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        paymaster.unpause();
    }

    function test_pauseAsOwner() public {
        vm.prank(owner);
        paymaster.pause();
        assert(paymaster.paused());
    }

    function test_unpauseAsOwner() public {
        vm.prank(owner);
        paymaster.pause();
        assert(paymaster.paused());
        vm.prank(owner);
        paymaster.unpause();
        assert(!paymaster.paused());
    }

    function test_UpdateMaxCostAllowedNotAsOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        paymaster.updateMaxCostAllowed(100);
    }

    function test_UpdateMaxCostAllowedAsOwner() public {
        vm.prank(owner);
        paymaster.updateMaxCostAllowed(100);
        assertEq(paymaster.getMaxCostAllowed(), 100);
    }

    /*
     * ERC20 Balance tests
     */
    function test_NoERC20Balance() public {
        vm.expectRevert(SenderDoesNotHoldAnyERC20Tokens.selector);
        paymasterHarness.exposed_verifyERC20Holdings(alice);
    }

    function test_ERC20Balance() public {
        vm.prank(owner);
        erc20.mint(alice, 100);
        paymasterHarness.exposed_verifyERC20Holdings(alice);
    }

    /*
     * Verify Call Data for CastVote Action Tests
     */

    function testFuzzing_callDataNot228Bytes(bytes memory callData) public {
        vm.assume(callData.length != 228);
        vm.expectRevert(IncorrectCallDataLengthOf228Bytes.selector);
        paymasterHarness.exposed_verifyCallDataForCastVoteAction(callData);
    }

    function test_callDataIncorrectExecuteSig() public {
        bytes memory callDataWithIncorrectExecuteSig = hex"03033003" // incorrect execute signature
            hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // governorBravoAddress
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"56781388" // "castVote" signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId
            hex"0000000000000000000000000000000000000000000000000000000000000001" // support
            hex"00000000000000000000000000000000000000000000000000000000"; // filler
        vm.expectRevert(IncorrectExecuteSignature.selector);
        paymasterHarness.exposed_verifyCallDataForCastVoteAction(callDataWithIncorrectExecuteSig);
    }

    function test_callDataIncorrectGovernorBravoAddress() public {
        bytes memory callDataWithIncorrectERC20Address = hex"b61d27f6" // execute signature
            hex"0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984" // incorrect governorBravoAddress
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"56781388" // "castVote" signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId
            hex"0000000000000000000000000000000000000000000000000000000000000001" // support
            hex"00000000000000000000000000000000000000000000000000000000"; // filler
        vm.expectRevert(InvalidGovernorBravoAddress.selector);
        paymasterHarness.exposed_verifyCallDataForCastVoteAction(callDataWithIncorrectERC20Address);
    }

    function test_callDataIncorrectValue() public {
        bytes memory callDataWithIncorrectValue = bytes.concat(
            hex"b61d27f6" hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // governorBravoAddress
            hex"0000000000000000000000000000000000000000000000000000000000000001" // incorrect value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"56781388" // "castVote" signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId
            hex"0000000000000000000000000000000000000000000000000000000000000001" // support
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.expectRevert(ValueMustBeZero.selector);
        paymasterHarness.exposed_verifyCallDataForCastVoteAction(callDataWithIncorrectValue);
    }

    function test_callDataIncorrectData1() public {
        bytes memory callDataWithIncorrectData1 = bytes.concat(
            hex"b61d27f6" hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // governorBravoAddress
            hex"0000000000000000000000000000000000000000000000000000000000000000" // incorrect value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000061" // incorrect data1
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2 (0x44)
            hex"56781388" // "castVote" signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId
            hex"0000000000000000000000000000000000000000000000000000000000000001" // support
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.expectRevert(Data1MustBe0x60.selector);
        paymasterHarness.exposed_verifyCallDataForCastVoteAction(callDataWithIncorrectData1);
    }

    function test_callDataIncorrectData2() public {
        bytes memory callDataWithIncorrectData2 = bytes.concat(
            hex"b61d27f6" hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // governorBravoAddress
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1
            hex"0000000000000000000000000000000000000000000000000000000000000045" // incorrect data2
            hex"56781388" // "castVote" signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId
            hex"0000000000000000000000000000000000000000000000000000000000000001" // support
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.expectRevert(Data2MustBe0x44.selector);
        paymasterHarness.exposed_verifyCallDataForCastVoteAction(callDataWithIncorrectData2);
    }

    function test_callDataIncorrectCastVoteSig() public {
        bytes memory callDataWithIncorrectCastVoteSig = bytes.concat(
            hex"b61d27f6" hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // governorBravoAddress
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2
            hex"56781387" // "castVote" signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId
            hex"0000000000000000000000000000000000000000000000000000000000000001" // support
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.expectRevert(IncorrectCastVoteSignature.selector);
        paymasterHarness.exposed_verifyCallDataForCastVoteAction(callDataWithIncorrectCastVoteSig);
    }

    function test_callDataIncorrectSupportValue() public {
        bytes memory callDataWithIncorrectSupport = bytes.concat(
            hex"b61d27f6" hex"000000000000000000000000408ed6354d4973f66138c91495f2f2fcbd8724c3" // governorBravoAddress
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1
            hex"0000000000000000000000000000000000000000000000000000000000000044" // data2
            hex"56781388" // "castVote" signature
            hex"0000000000000000000000000000000000000000000000000000000000000034" // proposalId
            hex"0000000000000000000000000000000000000000000000000000000000000003" // support
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.expectRevert(SupportMustBeLessThanOrEqualToTwo.selector);
        paymasterHarness.exposed_verifyCallDataForCastVoteAction(callDataWithIncorrectSupport);
    }

    /*
     * Validate UserOp
     */

    function test_validatePaymasterUserOpPaused() public {
        UserOperation memory userOp = _userOpsHelper(correctCallData, owner);
        vm.prank(owner);
        paymasterHarness.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
    }

    function test_validatePaymasterUserOpMaxCostTooHigh() public {
        UserOperation memory userOp = _userOpsHelper(correctCallData, owner);
        uint256 maxCost = paymasterHarness.getMaxCostAllowed() + 1;
        vm.expectRevert(abi.encodeWithSelector(MaxCostExceedsAllowedAmount.selector, maxCost));
        paymasterHarness.exposed_validaterPaymasterUserOp(userOp, maxCost);
    }

    // also tests postOpReverted
    function test_validatePaymasterUserOpUserOnBlocklist() public {
        // add Alice to blocklist
        paymasterHarness.exposed_postOp(IPaymaster.PostOpMode.opReverted, abi.encode(alice));
        UserOperation memory userOp = _userOpsHelper(correctCallData, alice);
        vm.expectRevert(SenderOnBlocklist.selector);
        paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
    }

    function test_validatePaymasterUserOpValidationData() public {
        // set timestamp
        vm.warp(30000);
        // give alice some erc20 tokens
        vm.prank(owner);
        erc20.mint(alice, 100);
        UserOperation memory userOp = _userOpsHelper(correctCallData, alice);
        (bytes memory context, uint256 validationData) = paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
        (address caller) = abi.decode(context, (address));
        assert(caller == alice);
    }

    /*
     * postOp Tests: same as above test, so not repeating here
     */
}
