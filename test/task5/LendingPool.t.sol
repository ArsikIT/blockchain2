// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../src/task1/MockERC20.sol";
import {MockPriceOracle} from "../../src/task5/MockPriceOracle.sol";
import {LendingPool} from "../../src/task5/LendingPool.sol";

contract LendingPoolTest is Test {
    event Deposited(address indexed user, uint256 amount);
    event Borrowed(address indexed user, uint256 amount);
    event Repaid(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event Liquidated(
        address indexed liquidator,
        address indexed user,
        uint256 repaidAmount,
        uint256 collateralSeized
    );

    MockERC20 internal collateralToken;
    MockERC20 internal debtToken;
    MockPriceOracle internal oracle;
    LendingPool internal pool;

    address internal alice = makeAddr("alice");
    address internal bob = makeAddr("bob");
    address internal liquidator = makeAddr("liquidator");

    uint256 internal constant RATE_BPS = 1000; // 10% annual

    function setUp() public {
        collateralToken = new MockERC20("Collateral", "COL");
        debtToken = new MockERC20("Debt", "DEBT");
        oracle = new MockPriceOracle(2 ether, 1 ether);
        pool = new LendingPool(address(collateralToken), address(debtToken), address(oracle), RATE_BPS);

        _mintAndApprove(alice, 10_000 ether, 10_000 ether);
        _mintAndApprove(bob, 10_000 ether, 10_000 ether);
        _mintAndApprove(liquidator, 10_000 ether, 10_000 ether);

        debtToken.mint(address(pool), 50_000 ether);
    }

    function test_DepositUpdatesPositionAndTransfersCollateral() public {
        vm.expectEmit(true, false, false, true);
        emit Deposited(alice, 100 ether);

        vm.prank(alice);
        pool.deposit(100 ether);

        (uint256 deposited, uint256 borrowed,) = pool.getPosition(alice);
        assertEq(deposited, 100 ether);
        assertEq(borrowed, 0);
        assertEq(collateralToken.balanceOf(address(pool)), 100 ether);
    }

    function test_WithdrawReturnsCollateralWhenNoDebt() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);

        vm.expectEmit(true, false, false, true);
        emit Withdrawn(alice, 40 ether);
        pool.withdraw(40 ether);
        vm.stopPrank();

        (uint256 deposited,,) = pool.getPosition(alice);
        assertEq(deposited, 60 ether);
        assertEq(collateralToken.balanceOf(alice), 9_940 ether);
    }

    function test_BorrowWithinLtvSucceeds() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);

        vm.expectEmit(true, false, false, true);
        emit Borrowed(alice, 120 ether);
        pool.borrow(120 ether);
        vm.stopPrank();

        (, uint256 borrowed, uint256 healthFactor) = pool.getPosition(alice);
        assertEq(borrowed, 120 ether);
        assertGt(healthFactor, 1e18);
        assertEq(debtToken.balanceOf(alice), 10_120 ether);
    }

    function test_BorrowExceedingLtvReverts() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        vm.expectRevert(LendingPool.ExceedsMaxLtv.selector);
        pool.borrow(151 ether);
        vm.stopPrank();
    }

    function test_BorrowWithZeroCollateralReverts() public {
        vm.prank(alice);
        vm.expectRevert(LendingPool.InsufficientCollateral.selector);
        pool.borrow(1 ether);
    }

    function test_RepayPartiallyReducesDebt() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(120 ether);

        vm.expectEmit(true, false, false, true);
        emit Repaid(alice, 20 ether);
        uint256 repaid = pool.repay(20 ether);
        vm.stopPrank();

        assertEq(repaid, 20 ether);
        (, uint256 borrowed,) = pool.getPosition(alice);
        assertEq(borrowed, 100 ether);
    }

    function test_RepayFullyCapsAtOutstandingDebt() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(100 ether);

        uint256 repaid = pool.repay(500 ether);
        vm.stopPrank();

        assertEq(repaid, 100 ether);
        (, uint256 borrowed, uint256 healthFactor) = pool.getPosition(alice);
        assertEq(borrowed, 0);
        assertEq(healthFactor, type(uint256).max);
    }

    function test_WithdrawWithOutstandingDebtRevertsWhenHealthFactorFallsBelowOne() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(140 ether);

        vm.expectRevert();
        pool.withdraw(10 ether);
        vm.stopPrank();
    }

    function test_WithdrawWithOutstandingDebtSucceedsWhenStillHealthy() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(100 ether);
        pool.withdraw(20 ether);
        vm.stopPrank();

        (uint256 deposited, uint256 borrowed, uint256 healthFactor) = pool.getPosition(alice);
        assertEq(deposited, 80 ether);
        assertEq(borrowed, 100 ether);
        assertGt(healthFactor, 1e18);
    }

    function test_InterestAccruesOverTime() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(100 ether);
        vm.stopPrank();

        vm.warp(block.timestamp + 365 days);

        uint256 previewDebt = pool.previewDebt(alice);
        assertEq(previewDebt, 110 ether);
    }

    function test_LiquidationWorksAfterPriceDrop() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(120 ether);
        vm.stopPrank();

        oracle.setCollateralPrice(1 ether);

        uint256 healthFactorBefore = pool.healthFactor(alice);
        assertLt(healthFactorBefore, 1e18);

        vm.expectEmit(true, true, false, false);
        emit Liquidated(liquidator, alice, 60 ether, 0);

        vm.prank(liquidator);
        (uint256 repaid, uint256 collateralSeized) = pool.liquidate(alice, 60 ether);

        assertEq(repaid, 60 ether);
        assertEq(collateralSeized, 63 ether);

        (uint256 deposited, uint256 borrowed,) = pool.getPosition(alice);
        assertEq(deposited, 37 ether);
        assertEq(borrowed, 60 ether);
        assertEq(collateralToken.balanceOf(liquidator), 10_063 ether);
    }

    function test_LiquidationRevertsWhilePositionIsHealthy() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(100 ether);
        vm.stopPrank();

        vm.prank(liquidator);
        vm.expectRevert(LendingPool.PositionHealthy.selector);
        pool.liquidate(alice, 50 ether);
    }

    function test_GetPositionReturnsDepositedBorrowedAndHealthFactor() public {
        vm.startPrank(alice);
        pool.deposit(100 ether);
        pool.borrow(100 ether);
        vm.stopPrank();

        (uint256 deposited, uint256 borrowed, uint256 healthFactor) = pool.getPosition(alice);
        assertEq(deposited, 100 ether);
        assertEq(borrowed, 100 ether);
        assertEq(healthFactor, 1_500_000_000_000_000_000);
    }

    function _mintAndApprove(address user, uint256 collateralAmount, uint256 debtAmount) internal {
        collateralToken.mint(user, collateralAmount);
        debtToken.mint(user, debtAmount);

        vm.startPrank(user);
        collateralToken.approve(address(pool), type(uint256).max);
        debtToken.approve(address(pool), type(uint256).max);
        vm.stopPrank();
    }
}
