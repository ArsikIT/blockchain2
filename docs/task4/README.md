# Task 4: AMM Mathematical Analysis

## 1. Constant Product Formula and Why It Works

The AMM in this assignment follows the constant product market maker model:

```text
x * y = k
```

Where:

- `x` is the reserve of token A
- `y` is the reserve of token B
- `k` is the pool invariant

The idea is that the pool always holds both assets, and the product of the reserves defines the pricing curve. If a trader adds more of token A into the pool, the reserve `x` increases. To keep trading consistent, the reserve `y` that remains in the pool must decrease, so the trader receives some token B out. Because the pool moves along the curve `x * y = k`, the exchange rate is not fixed; it changes as reserves change.

This mechanism works because price becomes an emergent property of the reserve ratio rather than something manually set by an order book. The marginal price of token A in terms of token B is approximately:

```text
price(A) ~= y / x
```

and similarly:

```text
price(B) ~= x / y
```

When one side of the pool becomes scarcer, that asset becomes more expensive. This automatically discourages traders from draining the pool too far in one direction and creates continuous liquidity at all points on the curve.

In the implemented AMM, the output amount for a trade is computed with the standard constant-product formula plus fees:

```text
amountInWithFee = amountIn * 997
amountOut = (amountInWithFee * reserveOut) / (reserveIn * 1000 + amountInWithFee)
```

This means only `99.7%` of the input amount is treated as effective swap input, while `0.3%` stays in the pool as a fee.

## 2. Effect of the 0.3% Fee on the Invariant

In a fee-free constant product AMM, idealized swaps preserve:

```text
x * y = k
```

exactly, ignoring integer rounding. However, with a `0.3%` fee, not all of the trader's input contributes to the pricing equation. A small fraction remains in the pool. This causes the post-trade reserves to produce:

```text
k_after >= k_before
```

Instead of remaining exactly constant.

This happens because the trader pays in the full amount, but the pool calculates output using only:

```text
amountIn * 0.997
```

As effective input. The remaining `0.003 * amountIn` stays inside the reserves and benefits liquidity providers. Over time, repeated swaps accumulate fees in the pool, so the invariant tends to increase. That is why, in practice, LP positions gain fee revenue even when the price changes expose them to impermanent loss.

In this assignment's implementation, this behavior is visible in testing: after a swap, the reserve product is verified to stay the same or increase. That matches the mathematical expectation of a fee-charging constant product market maker.

## 3. Impermanent Loss

Impermanent loss (IL) is the difference between:

- the value of providing liquidity to the AMM
- the value of simply holding the two assets outside the pool

Suppose an LP initially deposits equal-value amounts of two assets when the relative price is normalized to `1`. Let the external price later change by a factor `r`. In a constant product AMM, arbitrage trading will rebalance the pool until the reserve ratio reflects the new market price.

The standard impermanent loss formula is:

```text
IL(r) = (2 * sqrt(r) / (1 + r)) - 1
```

This value is usually negative, because LP value is lower than simple holding unless trading fees compensate for the loss.

### IL for a 2x Price Change

For a price move of `2x`, let:

```text
r = 2
```

Then:

```text
IL(2) = (2 * sqrt(2) / (1 + 2)) - 1
      = (2 * 1.41421356 / 3) - 1
      = 2.82842712 / 3 - 1
      = 0.94280904 - 1
      = -0.05719096
```

So the impermanent loss is approximately:

```text
-5.72%
```

This means that if the asset price doubles, the LP position is worth about `5.72%` less than a simple buy-and-hold position, before accounting for trading fees. The loss is called "impermanent" because if the price later returns to its original ratio, the loss disappears. If the LP withdraws while the price is still changed, the loss becomes realized.

## 4. Price Impact as a Function of Trade Size

Price impact is the change in execution price caused by the trade itself. In a constant product AMM, larger trades push the pool further along the curve and therefore receive progressively worse execution.

For reserves `x` and `y`, a trade that adds `dx` of token A changes reserves to:

```text
x' = x + dx
y' = k / x'
```

So the output amount is:

```text
dy = y - y' = y - k / (x + dx)
```

The average execution price for the trade is:

```text
price_exec = dx / dy
```

The spot price before the trade is approximately:

```text
price_spot = x / y
```

As `dx` becomes larger relative to `x`, the trader moves deeper along the curve, and the gap between spot price and execution price grows. This is why price impact is fundamentally a function of trade size relative to pool reserves:

- small trade compared with reserves -> low slippage, low price impact
- large trade compared with reserves -> high slippage, high price impact

This effect is visible in the implemented tests. A small swap receives a much better per-unit output than a swap consuming a large fraction of the pool. That is expected because liquidity is not linear; it follows the curvature of `x * y = k`.

## 5. Comparison with Uniswap V2

The AMM built for this assignment is conceptually close to Uniswap V2 because it uses:

- a two-token pool
- the constant product rule
- LP tokens for liquidity shares
- proportional deposits and withdrawals
- a `0.3%` fee

However, several features from Uniswap V2 are missing:

### Missing Feature 1: Factory and Pair Architecture

Uniswap V2 uses a factory contract that creates and tracks many pair contracts. This assignment has a single standalone AMM instance for one token pair.

### Missing Feature 2: Router Abstraction

Uniswap V2 exposes a router that handles multi-step swaps, path routing, ETH wrapping, and helper functions for users. This assignment interacts directly with one AMM contract and only supports one pair.

### Missing Feature 3: Protocol-Level Safety and Edge Handling

Uniswap V2 contains production-grade checks and battle-tested design decisions for reserve syncing, minimum liquidity locking, and interoperability. This assignment is intentionally simplified and focuses on the core mechanics.

### Missing Feature 4: Oracle/TWAP Features

Uniswap V2 tracks cumulative prices that can be used to derive time-weighted average prices (TWAPs). This assignment does not include oracle-related logic.

### Missing Feature 5: Broader Ecosystem Integration

Uniswap V2 is part of a larger ecosystem with analytics, frontends, routing, arbitrage integration, and widespread token compatibility. This assignment is a minimal educational implementation.

## Conclusion

The constant product AMM works by enforcing a reserve curve rather than matching orders directly. This gives continuous liquidity and automatic price discovery based on pool balances. The `0.3%` fee causes the invariant to increase over time, which is the mechanism through which LPs earn fees. At the same time, LPs face impermanent loss when relative prices move, with a `2x` price move producing approximately `5.72%` IL before fees. Finally, price impact grows nonlinearly with trade size relative to pool depth, which is why deep liquidity is important for efficient execution.

The implementation in this assignment captures the essential economics of Uniswap V2-style AMMs, while intentionally omitting the more advanced infrastructure and production-level features of the real protocol.
