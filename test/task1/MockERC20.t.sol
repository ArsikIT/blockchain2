// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../src/task1/MockERC20.sol";

contract MockERC20Test is Test {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    MockERC20 internal token;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal carol = makeAddr("carol");

    uint256 internal constant INITIAL_ALICE_BALANCE = 1_000 ether;
    uint256 internal constant INITIAL_BOB_BALANCE = 250 ether;

    function setUp() public {
        token = new MockERC20("Assignment Token", "ATK");
        token.mint(alice, INITIAL_ALICE_BALANCE);
        token.mint(bob, INITIAL_BOB_BALANCE);
    }

    function test_MetadataIsConfigured() public view {
        assertEq(token.name(), "Assignment Token");
        assertEq(token.symbol(), "ATK");
        assertEq(token.decimals(), 18);
    }

    function test_MintIncreasesBalanceAndSupply() public {
        token.mint(carol, 50 ether);

        assertEq(token.balanceOf(carol), 50 ether);
        assertEq(token.totalSupply(), INITIAL_ALICE_BALANCE + INITIAL_BOB_BALANCE + 50 ether);
    }

    function test_MintRevertsForZeroAddress() public {
        vm.expectRevert(MockERC20.ZeroAddress.selector);
        token.mint(address(0), 1 ether);
    }

    function test_TransferMovesBalance() public {
        vm.prank(alice);
        bool success = token.transfer(bob, 100 ether);

        assertTrue(success);
        assertEq(token.balanceOf(alice), 900 ether);
        assertEq(token.balanceOf(bob), 350 ether);
    }

    function test_TransferEmitsEvent() public {
        vm.expectEmit(true, true, false, true);
        emit Transfer(alice, bob, 25 ether);

        vm.prank(alice);
        token.transfer(bob, 25 ether);
    }

    function test_TransferRevertsWhenBalanceTooLow() public {
        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MockERC20.InsufficientBalance.selector, INITIAL_BOB_BALANCE, 500 ether));
        token.transfer(alice, 500 ether);
    }

    function test_TransferRevertsForZeroRecipient() public {
        vm.prank(alice);
        vm.expectRevert(MockERC20.ZeroAddress.selector);
        token.transfer(address(0), 1 ether);
    }

    function test_ApproveSetsAllowance() public {
        vm.expectEmit(true, true, false, true);
        emit Approval(alice, bob, 75 ether);

        vm.prank(alice);
        bool success = token.approve(bob, 75 ether);

        assertTrue(success);
        assertEq(token.allowance(alice, bob), 75 ether);
    }

    function test_ApproveRevertsForZeroSpender() public {
        vm.prank(alice);
        vm.expectRevert(MockERC20.ZeroAddress.selector);
        token.approve(address(0), 1 ether);
    }

    function test_TransferFromMovesFundsAndUpdatesAllowance() public {
        vm.prank(alice);
        token.approve(bob, 200 ether);

        vm.prank(bob);
        bool success = token.transferFrom(alice, carol, 120 ether);

        assertTrue(success);
        assertEq(token.balanceOf(alice), 880 ether);
        assertEq(token.balanceOf(carol), 120 ether);
        assertEq(token.allowance(alice, bob), 80 ether);
    }

    function test_TransferFromWithMaxAllowanceDoesNotDecreaseAllowance() public {
        vm.prank(alice);
        token.approve(bob, type(uint256).max);

        vm.prank(bob);
        token.transferFrom(alice, carol, 20 ether);

        assertEq(token.allowance(alice, bob), type(uint256).max);
    }

    function test_TransferFromRevertsWhenAllowanceTooLow() public {
        vm.prank(alice);
        token.approve(bob, 10 ether);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MockERC20.InsufficientAllowance.selector, 10 ether, 11 ether));
        token.transferFrom(alice, carol, 11 ether);
    }

    function test_TransferFromRevertsWhenOwnerBalanceTooLow() public {
        vm.prank(alice);
        token.approve(bob, 2_000 ether);

        vm.prank(bob);
        vm.expectRevert(abi.encodeWithSelector(MockERC20.InsufficientBalance.selector, INITIAL_ALICE_BALANCE, 2_000 ether));
        token.transferFrom(alice, carol, 2_000 ether);
    }

    function testFuzz_TransferConservesSupply(uint256 amount, address recipient) public {
        vm.assume(recipient != address(0));
        vm.assume(recipient != alice);

        amount = bound(amount, 0, INITIAL_ALICE_BALANCE);

        uint256 totalSupplyBefore = token.totalSupply();
        uint256 senderBalanceBefore = token.balanceOf(alice);
        uint256 recipientBalanceBefore = token.balanceOf(recipient);

        vm.prank(alice);
        bool success = token.transfer(recipient, amount);

        assertTrue(success);
        assertEq(token.balanceOf(alice), senderBalanceBefore - amount);
        assertEq(token.balanceOf(recipient), recipientBalanceBefore + amount);
        assertEq(token.totalSupply(), totalSupplyBefore);
    }
}
