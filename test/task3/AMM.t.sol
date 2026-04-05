// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {AMM} from "../../src/task3/AMM.sol";
import {MockERC20} from "../../src/task1/MockERC20.sol";
import {LPToken} from "../../src/task3/LPToken.sol";

contract AMMTest is Test {
    event LiquidityAdded(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidityMinted);
    event LiquidityRemoved(address indexed provider, uint256 amount0, uint256 amount1, uint256 liquidityBurned);
    event Swap(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    MockERC20 internal tokenA;
    MockERC20 internal tokenB;
    AMM internal amm;
    LPToken internal lpToken;

    address internal liquidityProvider1 = makeAddr("liquidityProvider1");
    address internal liquidityProvider2 = makeAddr("liquidityProvider2");
    address internal trader = makeAddr("trader");

    function setUp() public {
        tokenA = new MockERC20("Token A", "TKA");
        tokenB = new MockERC20("Token B", "TKB");
        amm = new AMM(address(tokenA), address(tokenB));
        lpToken = amm.lpToken();

        _mintAndApprove(liquidityProvider1, 100_000 ether, 100_000 ether);
        _mintAndApprove(liquidityProvider2, 100_000 ether, 100_000 ether);
        _mintAndApprove(trader, 100_000 ether, 100_000 ether);
    }

    function test_AddLiquidityFirstProviderMintsLpTokens() public {
        vm.expectEmit(true, false, false, true);
        emit LiquidityAdded(liquidityProvider1, 1_000 ether, 1_000 ether, 1_000 ether);

        vm.prank(liquidityProvider1);
        uint256 minted = amm.addLiquidity(1_000 ether, 1_000 ether);

        assertEq(minted, 1_000 ether);
        assertEq(lpToken.balanceOf(liquidityProvider1), 1_000 ether);
        assertEq(amm.reserve0(), 1_000 ether);
        assertEq(amm.reserve1(), 1_000 ether);
    }

    function test_AddLiquiditySecondProviderRequiresProportionalDeposit() public {
        vm.prank(liquidityProvider1);
        amm.addLiquidity(1_000 ether, 1_000 ether);

        vm.prank(liquidityProvider2);
        uint256 minted = amm.addLiquidity(500 ether, 500 ether);

        assertEq(minted, 500 ether);
        assertEq(lpToken.balanceOf(liquidityProvider2), 500 ether);
        assertEq(amm.reserve0(), 1_500 ether);
        assertEq(amm.reserve1(), 1_500 ether);
    }

    function test_AddLiquidityRevertsForSingleSidedDeposit() public {
        vm.prank(liquidityProvider1);
        vm.expectRevert(AMM.ZeroAmount.selector);
        amm.addLiquidity(1_000 ether, 0);
    }

    function test_AddLiquidityRevertsForWrongRatio() public {
        vm.prank(liquidityProvider1);
        amm.addLiquidity(1_000 ether, 1_000 ether);

        vm.prank(liquidityProvider2);
        vm.expectRevert(AMM.InvalidLiquidityRatio.selector);
        amm.addLiquidity(500 ether, 400 ether);
    }

    function test_RemoveLiquidityPartiallyReturnsUnderlyingTokens() public {
        vm.prank(liquidityProvider1);
        amm.addLiquidity(1_000 ether, 1_000 ether);

        vm.expectEmit(true, false, false, true);
        emit LiquidityRemoved(liquidityProvider1, 400 ether, 400 ether, 400 ether);

        vm.prank(liquidityProvider1);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(400 ether);

        assertEq(amountA, 400 ether);
        assertEq(amountB, 400 ether);
        assertEq(lpToken.balanceOf(liquidityProvider1), 600 ether);
        assertEq(amm.reserve0(), 600 ether);
        assertEq(amm.reserve1(), 600 ether);
    }

    function test_RemoveLiquidityFullyReturnsAllUnderlyingTokens() public {
        vm.prank(liquidityProvider1);
        uint256 minted = amm.addLiquidity(1_000 ether, 1_000 ether);

        vm.prank(liquidityProvider1);
        (uint256 amountA, uint256 amountB) = amm.removeLiquidity(minted);

        assertEq(amountA, 1_000 ether);
        assertEq(amountB, 1_000 ether);
        assertEq(lpToken.balanceOf(liquidityProvider1), 0);
        assertEq(amm.reserve0(), 0);
        assertEq(amm.reserve1(), 0);
    }

    function test_RemoveLiquidityRevertsWhenAmountIsZero() public {
        vm.prank(liquidityProvider1);
        amm.addLiquidity(1_000 ether, 1_000 ether);

        vm.prank(liquidityProvider1);
        vm.expectRevert(AMM.ZeroAmount.selector);
        amm.removeLiquidity(0);
    }

    function test_SwapTokenAToTokenB() public {
        vm.prank(liquidityProvider1);
        amm.addLiquidity(5_000 ether, 5_000 ether);

        uint256 expectedOut = amm.getAmountOut(100 ether, amm.reserve0(), amm.reserve1());

        vm.expectEmit(true, true, true, true);
        emit Swap(trader, address(tokenA), address(tokenB), 100 ether, expectedOut);

        vm.prank(trader);
        uint256 amountOut = amm.swap(address(tokenA), 100 ether, expectedOut);

        assertEq(amountOut, expectedOut);
        assertEq(tokenB.balanceOf(trader), 100_000 ether + expectedOut);
        assertEq(amm.reserve0(), 5_100 ether);
        assertEq(amm.reserve1(), 5_000 ether - expectedOut);
    }

    function test_SwapTokenBToTokenA() public {
        vm.prank(liquidityProvider1);
        amm.addLiquidity(5_000 ether, 5_000 ether);

        uint256 expectedOut = amm.getAmountOut(250 ether, amm.reserve1(), amm.reserve0());

        vm.prank(trader);
        uint256 amountOut = amm.swap(address(tokenB), 250 ether, expectedOut);

        assertEq(amountOut, expectedOut);
        assertEq(tokenA.balanceOf(trader), 100_000 ether + expectedOut);
        assertEq(amm.reserve1(), 5_250 ether);
        assertEq(amm.reserve0(), 5_000 ether - expectedOut);
    }

    function test_SwapRevertsWhenMinimumOutputIsTooHigh() public {
        vm.prank(liquidityProvider1);
        amm.addLiquidity(5_000 ether, 5_000 ether);

        uint256 expectedOut = amm.getAmountOut(100 ether, amm.reserve0(), amm.reserve1());

        vm.prank(trader);
        vm.expectRevert(abi.encodeWithSelector(AMM.InsufficientOutputAmount.selector, expectedOut, expectedOut + 1));
        amm.swap(address(tokenA), 100 ether, expectedOut + 1);
    }

    function test_SwapRevertsForZeroAmount() public {
        vm.prank(liquidityProvider1);
        amm.addLiquidity(5_000 ether, 5_000 ether);

        vm.prank(trader);
        vm.expectRevert(AMM.ZeroAmount.selector);
        amm.swap(address(tokenA), 0, 0);
    }

    function test_SwapRevertsForUnknownToken() public {
        MockERC20 fakeToken = new MockERC20("Fake", "FAKE");

        vm.prank(liquidityProvider1);
        amm.addLiquidity(5_000 ether, 5_000 ether);

        vm.prank(trader);
        vm.expectRevert(AMM.InvalidSwapToken.selector);
        amm.swap(address(fakeToken), 1 ether, 0);
    }

    function test_GetAmountOutAppliesPointThreePercentFee() public view {
        uint256 output = amm.getAmountOut(100 ether, 1_000 ether, 1_000 ether);

        assertEq(output, 90.661089388014913158 ether);
    }

    function test_KIncreasesAfterSwapDueToFees() public {
        vm.prank(liquidityProvider1);
        amm.addLiquidity(5_000 ether, 5_000 ether);

        uint256 kBefore = amm.reserve0() * amm.reserve1();

        vm.prank(trader);
        amm.swap(address(tokenA), 500 ether, 0);

        uint256 kAfter = amm.reserve0() * amm.reserve1();
        assertGe(kAfter, kBefore);
    }

    function test_LargeSwapHasHighPriceImpact() public {
        vm.prank(liquidityProvider1);
        amm.addLiquidity(5_000 ether, 5_000 ether);

        uint256 smallTradeOut = amm.getAmountOut(10 ether, amm.reserve0(), amm.reserve1());
        uint256 largeTradeOut = amm.getAmountOut(2_500 ether, amm.reserve0(), amm.reserve1());

        assertLt(largeTradeOut / 2_500, smallTradeOut / 10);
    }

    function testFuzz_SwapPreservesOrIncreasesInvariant(uint256 liquidityA, uint256 liquidityB, uint256 amountIn) public {
        liquidityA = bound(liquidityA, 1_000 ether, 100_000 ether);
        liquidityB = bound(liquidityB, 1_000 ether, 100_000 ether);
        amountIn = bound(amountIn, 1, 10_000 ether);

        vm.prank(liquidityProvider1);
        amm.addLiquidity(liquidityA, liquidityB);

        uint256 kBefore = amm.reserve0() * amm.reserve1();
        uint256 expectedOut = amm.getAmountOut(amountIn, amm.reserve0(), amm.reserve1());

        vm.prank(trader);
        uint256 amountOut = amm.swap(address(tokenA), amountIn, 0);

        uint256 kAfter = amm.reserve0() * amm.reserve1();

        assertEq(amountOut, expectedOut);
        assertLe(amountOut, amm.reserve1() + amountOut);
        assertGe(kAfter, kBefore);
    }

    function _mintAndApprove(address user, uint256 amountA, uint256 amountB) internal {
        tokenA.mint(user, amountA);
        tokenB.mint(user, amountB);

        vm.startPrank(user);
        tokenA.approve(address(amm), type(uint256).max);
        tokenB.approve(address(amm), type(uint256).max);
        vm.stopPrank();
    }
}
