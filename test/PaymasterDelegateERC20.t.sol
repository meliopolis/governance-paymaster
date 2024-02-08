// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import "forge-std/Test.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/cryptography/EIP712.sol";
import "../src/PaymasterDelegateERC20.sol";

contract ERC20Test is ERC20, ERC20Votes, Ownable {
    constructor() ERC20("Test Token", "TST") EIP712("Test Token", "1") Ownable(msg.sender) {}

    function _update(address from, address to, uint256 value) internal override(ERC20, ERC20Votes) {
        super._update(from, to, value);
    }

    function mint(address to, uint256 amount) public onlyOwner {
        _mint(to, amount);
    }
}

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
}

contract PaymasterDelegateERC20Test is Test {
    PaymasterDelegateERC20 public paymaster;
    PaymasterDelegateERC20Harness public paymasterHarness;
    ERC20Test erc20;
    address owner = vm.envAddress("PUBLIC_KEY");
    address entryPointAddress = vm.envAddress("ENTRY_POINT");
    address alice = address(0x1);
    address bob = address(0x2);

    bytes correctCallData = hex"b61d27f6" // execute signature
        hex"0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984" // ERC20 token address
        hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
        hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
        hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
        hex"5c19a95c" // "delegate" signature
        hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
        hex"00000000000000000000000000000000000000000000000000000000"; // filler

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
    function _userOpsHelper(bytes memory callData) internal view returns (UserOperation memory) {
        UserOperation memory userOp = UserOperation(address(owner), 0, hex"", callData, 0, 0, 0, 0, 0, hex"", hex"");
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
    function testFail_pauseNotAsOwner() public {
        paymaster.pause();
    }

    function testFail_unpauseNotAsOwner() public {
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

    function testFail_UpdateMaxCostAllowedNotAsOwner() public {
        paymaster.updateMaxCostAllowed(100);
    }

    function test_UpdateMaxCostAllowedAsOwner() public {
        vm.prank(owner);
        paymaster.updateMaxCostAllowed(100);
        assertEq(paymaster.getMaxCostAllowed(), 100);
    }

    function testFail_UpdateMinWaitBetweenDelegationsNotAsOwner() public {
        paymaster.updateMinWaitBetweenDelegations(100 days);
    }

    function testFail_UpdateMinWaitBetweenDelegationsAsOwnerLessThan1Day() public {
        vm.prank(owner);
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
        vm.expectRevert("callData must be 196 bytes");
        paymasterHarness.exposed_verifyCallDataForDelegateAction(callData);
    }

    function test_callDataIncorrectExecuteSig() public {
        bytes memory incorrectCallData = hex"03033003" // incorrect execute signature
            hex"0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984" // ERC20 token address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000"; // filler
        vm.expectRevert("incorrect execute signature");
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataIncorrectERC20Address() public {
        bytes memory incorrectCallData = hex"b61d27f6" // execute signature
            hex"0000000000000000000000001f9840a85d5af5bf1d1762f925bdaddc4201f984" // ERC20 token address
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000"; // filler
        vm.expectRevert("address needs to point to the ERC20 token address");
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataIncorrectValue() public {
        bytes memory incorrectCallData = bytes.concat(
            hex"b61d27f6",
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000001" // incorrect value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.expectRevert("value needs to be 0");
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataIncorrectData1() public {
        bytes memory incorrectCallData = bytes.concat(
            hex"b61d27f6",
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000061" // incorrect data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.expectRevert("data1 needs to be 0x60");
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataIncorrectData2() public {
        bytes memory incorrectCallData = bytes.concat(
            hex"b61d27f6",
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000025" // incorrect data2 (0x24)
            hex"5c19a95c" // "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.expectRevert("data2 needs to be 0x24");
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataIncorrectDelegateSig() public {
        bytes memory incorrectCallData = bytes.concat(
            hex"b61d27f6",
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95d" // incorrect "delegate" signature
            hex"000000000000000000000000b6c7ff166b0d27aa6132673838995f0fa68c7676" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.expectRevert("incorrect delegate signature");
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    function test_callDataDelegateeIs0x0Address() public {
        bytes memory incorrectCallData = bytes.concat(
            hex"b61d27f6",
            bytes32(uint256(uint160(address(erc20)))),
            hex"0000000000000000000000000000000000000000000000000000000000000000" // value (payment)
            hex"0000000000000000000000000000000000000000000000000000000000000060" // data1 (0x60)
            hex"0000000000000000000000000000000000000000000000000000000000000024" // data2 (0x24)
            hex"5c19a95c" // incorrect "delegate" signature
            hex"0000000000000000000000000000000000000000000000000000000000000000" // delegatee
            hex"00000000000000000000000000000000000000000000000000000000" // filler
        );
        vm.expectRevert("delegatee cannot be 0x0");
        paymasterHarness.exposed_verifyCallDataForDelegateAction(incorrectCallData);
    }

    /*
     * Validate UserOp
     */

    // TODO: test pausedFunctionality

    function testFail_ValidateUserOpMaxCostTooHigh() public {
        UserOperation memory userOp = _userOpsHelper(correctCallData);
        uint256 maxCost = paymaster.getMaxCostAllowed() + 1;
        paymasterHarness.validatePaymasterUserOp(userOp, 0x0, maxCost);
    }

    // TODO test blocklist
    // TODO test validAfter

    /*
     * TODO postOp Tests
     */
}
