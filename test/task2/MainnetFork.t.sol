// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";

interface IERC20Minimal {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
}

interface IUniswapV2Router02 {
    function WETH() external pure returns (address);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);
}

contract MainnetForkTest is Test {
    address internal constant USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48;
    address internal constant UNISWAP_V2_ROUTER = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;

    IERC20Minimal internal usdc = IERC20Minimal(USDC);
    IUniswapV2Router02 internal router = IUniswapV2Router02(UNISWAP_V2_ROUTER);

    uint256 internal forkId;
    uint256 internal latestObservedBlock;
    uint256 internal baseForkBlock;
    address internal trader = makeAddr("trader");

    function setUp() public {
        string memory mainnetRpcUrl = vm.rpcUrl("mainnet");

        vm.createSelectFork(mainnetRpcUrl);
        latestObservedBlock = block.number;
        baseForkBlock = latestObservedBlock - 10;

        forkId = vm.createSelectFork(mainnetRpcUrl, baseForkBlock);
    }

    function test_ReadRealUSDCTotalSupply() public view {
        uint256 totalSupply = usdc.totalSupply();

        assertGt(totalSupply, 1_000_000_000e6, "USDC supply on mainnet should be large");
    }

    function test_SimulateUniswapV2SwapOnFork() public {
        vm.deal(trader, 2 ether);

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = USDC;

        uint256 usdcBalanceBefore = usdc.balanceOf(trader);
        uint256 traderEthBefore = trader.balance;

        vm.prank(trader);
        uint256[] memory amounts = router.swapExactETHForTokens{value: 1 ether}(
            0,
            path,
            trader,
            block.timestamp + 15 minutes
        );

        uint256 usdcBalanceAfter = usdc.balanceOf(trader);
        uint256 traderEthAfter = trader.balance;

        assertEq(amounts.length, 2);
        assertEq(amounts[0], 1 ether);
        assertGt(amounts[1], 0, "swap should output USDC");
        assertEq(usdcBalanceAfter - usdcBalanceBefore, amounts[1]);
        assertLt(traderEthAfter, traderEthBefore);
    }

    function test_RollForkAdvancesBlockNumber() public {
        uint256 blockBefore = block.number;
        uint256 targetBlock = blockBefore + 5;

        vm.rollFork(targetBlock);

        assertEq(block.number, targetBlock);
        assertLe(block.number, latestObservedBlock);
    }

    function test_CanCreateAndSwitchBetweenForkSnapshots() public {
        uint256 initialBlock = block.number;
        uint256 secondFork = vm.createFork(vm.rpcUrl("mainnet"), initialBlock + 5);

        vm.selectFork(secondFork);
        assertEq(block.number, initialBlock + 5);
        assertLe(block.number, latestObservedBlock);

        vm.selectFork(forkId);
        assertEq(block.number, initialBlock);
    }
}
