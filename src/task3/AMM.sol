// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {MockERC20} from "../task1/MockERC20.sol";
import {LPToken} from "./LPToken.sol";

contract AMM {
    error InvalidToken();
    error SameToken();
    error ZeroAmount();
    error InsufficientLiquidity();
    error InsufficientLiquidityMinted();
    error InsufficientOutputAmount(uint256 actualOutput, uint256 minimumOutput);
    error InvalidLiquidityRatio();
    error InvalidSwapToken();

    uint256 internal constant FEE_NUMERATOR = 997;
    uint256 internal constant FEE_DENOMINATOR = 1000;

    MockERC20 public immutable token0;
    MockERC20 public immutable token1;
    LPToken public immutable lpToken;

    uint256 public reserve0;
    uint256 public reserve1;

    event LiquidityAdded(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityMinted
    );
    event LiquidityRemoved(
        address indexed provider,
        uint256 amount0,
        uint256 amount1,
        uint256 liquidityBurned
    );
    event Swap(
        address indexed trader,
        address indexed tokenIn,
        address indexed tokenOut,
        uint256 amountIn,
        uint256 amountOut
    );

    constructor(address token0_, address token1_) {
        if (token0_ == address(0) || token1_ == address(0)) revert InvalidToken();
        if (token0_ == token1_) revert SameToken();

        token0 = MockERC20(token0_);
        token1 = MockERC20(token1_);
        lpToken = new LPToken(address(this));
    }

    function addLiquidity(uint256 amount0In, uint256 amount1In) external returns (uint256 liquidityMinted) {
        if (amount0In == 0 || amount1In == 0) revert ZeroAmount();

        token0.transferFrom(msg.sender, address(this), amount0In);
        token1.transferFrom(msg.sender, address(this), amount1In);

        uint256 lpSupply = lpToken.totalSupply();
        if (lpSupply == 0) {
            liquidityMinted = _sqrt(amount0In * amount1In);
        } else {
            if (reserve0 * amount1In != reserve1 * amount0In) revert InvalidLiquidityRatio();

            uint256 liquidity0 = (amount0In * lpSupply) / reserve0;
            uint256 liquidity1 = (amount1In * lpSupply) / reserve1;
            liquidityMinted = liquidity0 < liquidity1 ? liquidity0 : liquidity1;
        }

        if (liquidityMinted == 0) revert InsufficientLiquidityMinted();

        reserve0 += amount0In;
        reserve1 += amount1In;

        lpToken.mint(msg.sender, liquidityMinted);

        emit LiquidityAdded(msg.sender, amount0In, amount1In, liquidityMinted);
    }

    function removeLiquidity(uint256 liquidityAmount)
        external
        returns (uint256 amount0Out, uint256 amount1Out)
    {
        if (liquidityAmount == 0) revert ZeroAmount();

        uint256 lpSupply = lpToken.totalSupply();
        if (lpSupply == 0) revert InsufficientLiquidity();

        amount0Out = (liquidityAmount * reserve0) / lpSupply;
        amount1Out = (liquidityAmount * reserve1) / lpSupply;

        if (amount0Out == 0 || amount1Out == 0) revert InsufficientLiquidity();

        lpToken.burn(msg.sender, liquidityAmount);

        reserve0 -= amount0Out;
        reserve1 -= amount1Out;

        token0.transfer(msg.sender, amount0Out);
        token1.transfer(msg.sender, amount1Out);

        emit LiquidityRemoved(msg.sender, amount0Out, amount1Out, liquidityAmount);
    }

    function swap(address tokenIn, uint256 amountIn, uint256 minimumAmountOut)
        external
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();

        bool isToken0In = tokenIn == address(token0);
        bool isToken1In = tokenIn == address(token1);
        if (!isToken0In && !isToken1In) revert InvalidSwapToken();

        MockERC20 inputToken = isToken0In ? token0 : token1;
        MockERC20 outputToken = isToken0In ? token1 : token0;
        uint256 reserveIn = isToken0In ? reserve0 : reserve1;
        uint256 reserveOut = isToken0In ? reserve1 : reserve0;

        if (reserveIn == 0 || reserveOut == 0) revert InsufficientLiquidity();

        amountOut = getAmountOut(amountIn, reserveIn, reserveOut);
        if (amountOut < minimumAmountOut) {
            revert InsufficientOutputAmount(amountOut, minimumAmountOut);
        }

        inputToken.transferFrom(msg.sender, address(this), amountIn);
        outputToken.transfer(msg.sender, amountOut);

        if (isToken0In) {
            reserve0 += amountIn;
            reserve1 -= amountOut;
            emit Swap(msg.sender, address(token0), address(token1), amountIn, amountOut);
        } else {
            reserve1 += amountIn;
            reserve0 -= amountOut;
            emit Swap(msg.sender, address(token1), address(token0), amountIn, amountOut);
        }
    }

    function getAmountOut(uint256 amountIn, uint256 reserveIn_, uint256 reserveOut_)
        public
        pure
        returns (uint256 amountOut)
    {
        if (amountIn == 0) revert ZeroAmount();
        if (reserveIn_ == 0 || reserveOut_ == 0) revert InsufficientLiquidity();

        uint256 amountInWithFee = amountIn * FEE_NUMERATOR;
        uint256 numerator = amountInWithFee * reserveOut_;
        uint256 denominator = (reserveIn_ * FEE_DENOMINATOR) + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function currentInvariant() external view returns (uint256) {
        return reserve0 * reserve1;
    }

    function _sqrt(uint256 value) internal pure returns (uint256 result) {
        if (value == 0) return 0;

        uint256 x = value;
        result = (x + 1) / 2;
        uint256 y = x;

        while (result < y) {
            y = result;
            result = (x / result + result) / 2;
        }

        result = y;
    }
}
