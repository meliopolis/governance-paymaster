// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@account-abstraction/interfaces/IPaymaster.sol";
import "./ERC20.t.sol";
import "./PaymasterDelegateERC20Harness.t.sol";
import "../src/PaymasterDelegateERC20.sol";

contract PaymasterDelegateERC20Test is Test {
    PaymasterDelegateERC20 public paymaster;
    PaymasterDelegateERC20Harness public paymasterHarness;
    ERC20Test public erc20;
    address public owner = vm.envAddress("PUBLIC_KEY");
    address public entryPointAddress = vm.envAddress("ENTRY_POINT");
    address public alice = address(0x1);
    address public bob = address(0x2);

    // bytes correctCallData = hex"b61d27f6" // execute signature
    //     hex"0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984" // ERC20 token address
    //     hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
    //     hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
    //     hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
    //     hex"5c19a95c" // "delegate" signature
    //     hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
    //     hex"00000000000000000000000000000000000000000000000000000000"; // filler

    bytes public correctExecuteSig = hex"b61d27f6"; // execute signature
    bytes public sampleERC20Address = hex"0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984"; // ERC20 token address
    bytes public correctValue = hex"0000000000000000000000000000000000000000000000000000000000000000"; // value (payment)
    bytes public correctData1 = hex"0000000000000000000000000000000000000000000000000000000000000060"; // data1 (0x60)
    bytes public correctData2 = hex"0000000000000000000000000000000000000000000000000000000000000024"; // data2 (0x24)
    bytes public correctDelegateSig = hex"5c19a95c"; // "delegate" signature
    bytes public sampleDelegatee = hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676"; // delegatee
    bytes public correctFiller = hex"00000000000000000000000000000000000000000000000000000000"; // filler

    // bytes correctCallData = bytes.concat(
    //     executeSig,
    //     sampleERC20Address,
    //     value,
    //     data1,
    //     data2,
    //     delegateSig,
    //     sampleDelegatee,
    //     filler
    // );

    /*
     * Setup
     */
    function setUp() public {
        IEntryPoint entryPoint = IEntryPoint(entryPointAddress);
        vm.startPrank(owner, owner);
        erc20 = new ERC20Test();
        paymaster = new PaymasterDelegateERC20(entryPoint, address(erc20));
        paymasterHarness = new PaymasterDelegateERC20Harness(entryPoint, address(erc20));
        vm.stopPrank();
        // vm.roll(30000);
        // vm.warp(360000);
        // vm.prank(owner);
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
    function testFail_ERC20Balance() public view {
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

    function testFuzzing_callDataNot196Bytes(bytes memory callData) public {
        vm.assume(callData.length != 196);
        vm.expectRevert(IncorrectCallDataLengthOf196Bytes.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(callData);
    }

    function test_callDataIncorrectExecuteSig() public {
        bytes memory incorrectCallData = bytes.concat(hex"03033003", // incorrect execute signature
            sampleERC20Address,
            correctValue,
            correctData1,
            correctData2,
            correctDelegateSig,
            sampleDelegatee,
            correctFiller);
        vm.expectRevert(IncorrectExecuteSignature.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataIncorrectERC20Address() public {
        bytes memory incorrectCallData = bytes.concat(
            correctExecuteSig,
            sampleERC20Address,
            correctValue,
            correctData1,
            correctData2,
            correctDelegateSig,
            sampleDelegatee,
            correctFiller);
        vm.expectRevert(InvalidERC20Address.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataIncorrectValue() public {
        bytes memory incorrectCallData = bytes.concat(
            correctExecuteSig,
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000001", // incorrect value (payment)
            correctData1,
            correctData2,
            correctDelegateSig,
            sampleDelegatee,
            correctFiller);
        vm.expectRevert(ValueMustBeZero.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataIncorrectData1() public {
        bytes memory incorrectCallData = bytes.concat(
            correctExecuteSig,
            bytes32(uint256(uint160(address(erc20)))),
            correctValue,
            hex"0000000000000000000000000000000000000000000000000000000000000061", // incorrect data1 (0x60)
            correctData2,
            correctDelegateSig,
            sampleDelegatee,
            correctFiller);
        vm.expectRevert(Data1MustBe0x60.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataIncorrectData2() public {
        bytes memory incorrectCallData = bytes.concat(
            correctExecuteSig,
            bytes32(uint256(uint160(address(erc20)))),
            correctValue,
            correctData1,
            hex"0000000000000000000000000000000000000000000000000000000000000025", // incorrect data2 (0x24)
            correctDelegateSig,
            sampleDelegatee,
            correctFiller);
        vm.expectRevert(Data2MustBe0x24.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataIncorrectDelegateSig() public {
        bytes memory incorrectCallData = bytes.concat(
            correctExecuteSig,
            bytes32(uint256(uint160(address(erc20)))),
            correctValue,
            correctData1,
            correctData2,
            hex"5c19a95d", // incorrect "delegate" signature
            sampleDelegatee,
            correctFiller);
        vm.expectRevert(IncorrectDelegateSignature.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataDelegateeIs0x0Address() public {
        bytes memory incorrectCallData = bytes.concat(
            correctExecuteSig,
            bytes32(uint256(uint160(address(erc20)))),
            correctValue,
            correctData1,
            correctData2,
            correctDelegateSig,
            hex"0000000000000000000000000000000000000000000000000000000000000000", // delegatee
            correctFiller);
        vm.expectRevert(DelegateeCannotBe0x0.selector);
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    /*
     * Validate UserOp
     */

    function test_validatePaymasterUserOpPaused() public {
        bytes memory callData = bytes.concat(
            correctExecuteSig,
            bytes32(uint256(uint160(address(erc20)))),
            correctValue,
            correctData1,
            correctData2,
            correctDelegateSig,
            sampleDelegatee,
            correctFiller);
        UserOperation memory userOp = _userOpsHelper(callData, owner);
        vm.prank(owner);
        paymasterHarness.pause();
        vm.expectRevert(Pausable.EnforcedPause.selector);
        paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
    }

    function test_validatePaymasterUserOpMaxCostTooHigh() public {
        bytes memory callData = bytes.concat(
            correctExecuteSig,
            bytes32(uint256(uint160(address(erc20)))),
            correctValue,
            correctData1,
            correctData2,
            correctDelegateSig,
            sampleDelegatee,
            correctFiller);
        UserOperation memory userOp = _userOpsHelper(callData, owner);
        uint256 maxCost = paymasterHarness.getMaxCostAllowed() + 1;
        vm.expectRevert(abi.encodeWithSelector(MaxCostExceedsAllowedAmount.selector, maxCost));
        paymasterHarness.exposed_validaterPaymasterUserOp(userOp, maxCost);
    }

    // also tests postOpReverted
    function test_validatePaymasterUserOpUserOnBlocklist() public {
        // add Alice to blocklist
        paymasterHarness.exposed_postOp(IPaymaster.PostOpMode.opReverted, abi.encode(alice));
        
        bytes memory callData = bytes.concat(
            correctExecuteSig,
            bytes32(uint256(uint160(address(erc20)))),
            correctValue,
            correctData1,
            correctData2,
            correctDelegateSig,
            sampleDelegatee,
            correctFiller);
        UserOperation memory userOp = _userOpsHelper(callData, alice);
        vm.expectRevert(SenderOnBlocklist.selector);
        paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
    }

    // also tests OpSucceeded
    function test_validatePaymasterUserOpValidationData() public {
        // set timestamp
        vm.warp(30000);
        // give alice some erc20 tokens
        vm.prank(owner);
        erc20.mint(alice, 100);
        
        bytes memory callData = bytes.concat(
            correctExecuteSig,
            bytes32(uint256(uint160(address(erc20)))),
            correctValue,
            correctData1,
            correctData2,
            correctDelegateSig,
            sampleDelegatee,
            correctFiller);
        UserOperation memory userOp = _userOpsHelper(callData, alice);
        (bytes memory context, uint256 validationData) = paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
        (address caller) = abi.decode(context, (address));
        assert(caller == alice);
        address validation = address(uint160(validationData));
        uint48 validUntil = uint48(validationData >> 160);
        uint48 validAfter = uint48(validationData >> (160 + 48));
        require(validation == address(0), "validation should be 0");
        require(validUntil == 0, "validUntil should be 0");
        require(validAfter == uint48(paymasterHarness.getMinWaitBetweenDelegations()), "validAfter should be minWaitBetweenDelegations");
    }

    function test_validatePaymasterUserOpValidationDataAfterPostOpSucceeded() public {
        // set blocknumber
        uint256 timeStamp = 30000;
        vm.warp(timeStamp);

        // give alice some erc20 tokens
        vm.prank(owner);
        erc20.mint(alice, 100);

        // pretend first call went through
        paymasterHarness.exposed_postOp(IPaymaster.PostOpMode.opSucceeded, abi.encode(alice));

        // call once        
        bytes memory callData = bytes.concat(
            correctExecuteSig,
            bytes32(uint256(uint160(address(erc20)))),
            correctValue,
            correctData1,
            correctData2,
            correctDelegateSig,
            sampleDelegatee,
            correctFiller);
        UserOperation memory userOp = _userOpsHelper(callData, alice);
        
        // call second time
        vm.warp(30012);
        ( , uint256 validationData) = paymasterHarness.exposed_validaterPaymasterUserOp(userOp, 100);
        address validation = address(uint160(validationData));
        uint48 validUntil = uint48(validationData >> 160);
        uint48 validAfter = uint48(validationData >> (160 + 48));
        require(validation == address(0), "validation should be 0");
        require (validUntil == validAfter + 30 minutes, "validUntil should be validAfter + 30 minutes");
        require (validAfter == uint48(timeStamp + paymasterHarness.getMinWaitBetweenDelegations()), "validAfter should be timestamp + paymaster.getMinWaitBetweenDelegations");
    }

    /*
     * postOp Tests: same as above two tests, so not repeating here
     */

}
