// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/Console.sol";
import {UserOperation} from "@account-abstraction/interfaces/UserOperation.sol";
import {IEntryPoint} from "@account-abstraction/interfaces/IEntryPoint.sol";
import {IPaymaster} from "@account-abstraction/interfaces/IPaymaster.sol";
import {Ownable} from "@openzeppelin/access/Ownable.sol";
import {ERC20Test} from "./ERC20Test.sol";
import {PaymasterDelegateAndCastVoteHarness} from "./PaymasterDelegateAndCastVoteHarness.sol";
// solhint-disable-next-line no-global-import
import "../src/PaymasterDelegateAndCastVote.sol";

// solhint-disable func-name-mixedcase
// solhint-disable custom-errors

contract PaymasterDelegateAndCastVoteTest is Test {
    PaymasterDelegateAndCastVote public paymaster;
    PaymasterDelegateAndCastVoteHarness public paymasterHarness;
    ERC20Test public erc20;
    address public governorBravoAddress = 0x408ED6354d4973f66138C91495F2f2FCbd8724C3;
    address public owner = vm.envAddress("PUBLIC_KEY");
    address public entryPointAddress = vm.envAddress("ENTRY_POINT");
    address public alice = address(0x1);

    bytes public correctCallDataForDelegate;
    bytes public correctCallDataForCastVote;

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
    /*
     * Setup
     */
    function setUp() public {
        IEntryPoint entryPoint = IEntryPoint(entryPointAddress);
        vm.startPrank(owner, owner);
        erc20 = new ERC20Test();
        paymaster = new PaymasterDelegateAndCastVote(entryPoint, address(erc20), governorBravoAddress);
        paymasterHarness = new PaymasterDelegateAndCastVoteHarness(entryPoint, address(erc20), governorBravoAddress);
        correctCallDataForDelegate = bytes.concat(
            hex"b61d27f6", // execute signature
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        correctCallDataForCastVote = bytes.concat(
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

    function test_UpdateMinWaitBetweenDelegationsNotAsOwner() public {
        vm.prank(alice);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, alice));
        paymaster.updateMinWaitBetweenDelegations(100 days);
    }

    function test_UpdateMinWaitBetweenDelegationsAsOwnerLessThan1Day() public {
        vm.prank(owner);
        vm.expectRevert(MinDayMustBeGreaterThan1Day.selector);
        paymaster.updateMinWaitBetweenDelegations(100);
    }

    function test_UpdateMinWaitBetweenDelegations() public {
        vm.prank(owner);
        paymaster.updateMinWaitBetweenDelegations(100 days);
        assertEq(paymaster.getMinWaitBetweenDelegations(), 100 days);
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
     * Verify Call Data for Delegate Action Tests
     */

    function test_callDataForDelegateIncorrectExecuteSig() public {
        bytes memory callDataWithIncorrectExecuteSig = hex"03033003" // incorrect execute signature
            hex"0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984" // ERC20 token address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000"; // filler
        vm.expectRevert(IncorrectExecuteSignature.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(callDataWithIncorrectExecuteSig);
    }

    function test_callDataForDelegateIncorrectERC20Address() public {
        bytes memory callDataWithIncorrectERC20Address = hex"b61d27f6" // execute signature
            hex"0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984" // incorrect ERC20 token address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000"; // filler
        vm.expectRevert(InvalidERC20Address.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(callDataWithIncorrectERC20Address);
    }

    function test_callDataForDelegateIncorrectValue() public {
        bytes memory callDataWithIncorrectValue = bytes.concat(
            hex"b61d27f6",
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000001", // incorrect value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000"
        );
        vm.expectRevert(ValueMustBeZero.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(callDataWithIncorrectValue);
    }

    function test_callDataForDelegateIncorrectData1() public {
        bytes memory callDataWithIncorrectData1 = bytes.concat(
            hex"b61d27f6",
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000000", // incorrect value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000061", // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000"
        );
        vm.expectRevert(Data1MustBe0x60.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(callDataWithIncorrectData1);
    }

    function test_callDataForDelegateIncorrectData2() public {
        bytes memory callDataWithIncorrectData2 = bytes.concat(
            hex"b61d27f6",
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000000" // incorrect value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060", // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000025", // data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000"
        );
        vm.expectRevert(Data2ForDelegateMustBe0x24.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(callDataWithIncorrectData2);
    }

    function test_callDataForDelegateIncorrectDelegateSig() public {
        bytes memory callDataWithIncorrectDelegateSig = bytes.concat(
            hex"b61d27f6",
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000000" // incorrect value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024", // data2 (0x24)
            hex"5c19a95d", // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000"
        );
        vm.expectRevert(IncorrectDelegateSignature.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(callDataWithIncorrectDelegateSig);
    }

    function test_callDataForDelegateDelegateeIs0x0Address() public {
        bytes memory callDataWithIncorrectDelegatee = bytes.concat(
            hex"b61d27f6",
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000000" // incorrect value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c", // "delegate" signature
            hex"0000000000000000000000000000000000000000000000000000000000000000", // delegatee
            hex"00000000000000000000000000000000000000000000000000000000"
        );
        vm.expectRevert(DelegateeCannotBe0x0.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(callDataWithIncorrectDelegatee);
    }

    /*
     * Verify Call Data for CastVote Action Tests
     */

    function test_callDataForCastVoteIncorrectExecuteSig() public {
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

    function test_callDataForCastVoteIncorrectGovernorBravoAddress() public {
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

    function test_callDataForCastVoteIncorrectValue() public {
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

    function test_callDataForCastVoteIncorrectData1() public {
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

    function test_callDataForCastVoteIncorrectData2() public {
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
        vm.expectRevert(Data2ForCastVoteMustBe0x44.selector);
        paymasterHarness.exposed_verifyCallDataForCastVoteAction(callDataWithIncorrectData2);
    }

    function test_callDataForCastVoteIncorrectCastVoteSig() public {
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

    function test_callDataForCastVoteIncorrectSupportValue() public {
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
        UserOperation memory userOp = _userOpsHelper(correctCallDataForDelegate, owner);
        vm.prank(owner);
        paymasterHarness.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
    }

    function test_validatePaymasterUserOpMaxCostTooHigh() public {
        UserOperation memory userOp = _userOpsHelper(correctCallDataForDelegate, owner);
        uint256 maxCost = paymasterHarness.getMaxCostAllowed() + 1;
        vm.expectRevert(abi.encodeWithSelector(MaxCostExceedsAllowedAmount.selector, maxCost));
        paymasterHarness.exposed_validaterPaymasterUserOp(userOp, maxCost);
    }

    // also tests postOpReverted
    function test_validatePaymasterUserOpUserOnBlocklist() public {
        // add Alice to blocklist
        paymasterHarness.exposed_postOp(
            IPaymaster.PostOpMode.opReverted, abi.encode(alice, PaymasterDelegateAndCastVote.Action.DELEGATE)
        );
        UserOperation memory userOp = _userOpsHelper(correctCallDataForDelegate, alice);
        vm.expectRevert(SenderOnBlocklist.selector);
        paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
    }

    // test calldata length
    function testFuzzing_callDataNot196or228Bytes(bytes memory callData) public {
        vm.assume(callData.length != 196 && callData.length != 228);
        vm.prank(owner);
        erc20.mint(alice, 100);
        UserOperation memory userOp = UserOperation(address(alice), 0, hex"", callData, 0, 0, 0, 0, 0, hex"", hex"");
        vm.expectRevert(IncorrectCallDataLengthOf196OR228Bytes.selector);
        paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 10);
    }

    // also tests OpSucceeded
    function test_validatePaymasterUserOpValidationDataForDelegate() public {
        // set timestamp
        vm.warp(30000);
        // give alice some erc20 tokens
        vm.prank(owner);
        erc20.mint(alice, 100);
        UserOperation memory userOp = _userOpsHelper(correctCallDataForDelegate, alice);
        (bytes memory context, uint256 validationData) = paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
        (address caller, PaymasterDelegateAndCastVote.Action action) =
            abi.decode(context, (address, PaymasterDelegateAndCastVote.Action));
        assert(caller == alice);
        assert(action == PaymasterDelegateAndCastVote.Action.DELEGATE);
        address validation = address(uint160(validationData));
        uint48 validUntil = uint48(validationData >> 160);
        uint48 validAfter = uint48(validationData >> (160 + 48));
        require(validation == address(0), "validation should be 0");
        require(validUntil == 0, "validUntil should be 0");
        require(validAfter == uint48(paymasterHarness.getMinWaitBetweenDelegations()), "validAfter != minWait");
    }

    function test_validatePaymasterUserOpValidationDataForCastVote() public {
        // set timestamp
        vm.warp(30000);
        // give alice some erc20 tokens
        vm.prank(owner);
        erc20.mint(alice, 100);
        UserOperation memory userOp = _userOpsHelper(correctCallDataForCastVote, alice);
        (bytes memory context, uint256 validationData) = paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
        (address caller, PaymasterDelegateAndCastVote.Action action) =
            abi.decode(context, (address, PaymasterDelegateAndCastVote.Action));
        assert(caller == alice);
        assert(action == PaymasterDelegateAndCastVote.Action.CAST_VOTE);
        assert(validationData == 0);
    }

    function test_validatePaymasterUserOpValidationDataForDelegateAfterPostOpSucceeded() public {
        // set blocknumber
        uint256 timeStamp = 30000;
        vm.warp(timeStamp);

        // give alice some erc20 tokens
        vm.prank(owner);
        erc20.mint(alice, 100);

        // pretend first call went through
        paymasterHarness.exposed_postOp(
            IPaymaster.PostOpMode.opSucceeded, abi.encode(alice, PaymasterDelegateAndCastVote.Action.DELEGATE)
        );

        // call second time
        UserOperation memory userOp = _userOpsHelper(correctCallDataForDelegate, alice);
        vm.warp(30012);
        (, uint256 validationData) = paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
        address validation = address(uint160(validationData));
        uint48 validUntil = uint48(validationData >> 160);
        uint48 validAfter = uint48(validationData >> (160 + 48));
        require(validation == address(0), "validation should be 0");
        require(validUntil == validAfter + 30 minutes, "validUntil != validAfter+30mins");
        require(
            validAfter == uint48(timeStamp + paymasterHarness.getMinWaitBetweenDelegations()),
            "validAfter != timestamp+minWait"
        );
    }

    function test_validatePaymasterUserOpValidationDataForCastVoteAfterPostOpSucceeded() public {
        // set blocknumber
        uint256 timeStamp = 30000;
        vm.warp(timeStamp);

        // give alice some erc20 tokens
        vm.prank(owner);
        erc20.mint(alice, 100);

        // pretend first call went through
        paymasterHarness.exposed_postOp(
            IPaymaster.PostOpMode.opSucceeded, abi.encode(alice, PaymasterDelegateAndCastVote.Action.CAST_VOTE)
        );

        // call second time
        UserOperation memory userOp = _userOpsHelper(correctCallDataForCastVote, alice);
        vm.warp(30012);
        (, uint256 validationData) = paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
        assert(validationData == 0);
    }

    /*
     * postOp Tests: same as above two tests, so not repeating here
     */
}
