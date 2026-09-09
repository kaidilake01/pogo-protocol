# Bonding-curve economics

All amounts below refer to a new standard curve (version 5). Read each existing pool's actual parameters and version.

Let `T` be the net quote-asset graduation target, `V = ceil(T × 25 / 73)` the virtual quote reserve, `S = 800,000,000 × 10^18` the sale allocation, and `H = ceil(S × (T + V) / T)` the initial virtual token reserve. Initial real supply is `1,000,000,000 × 10^18`; the virtual token offset is `H - initialSupply`.

For a buy with net input `n`, current real token reserve `rT` and real quote reserve `rQ`:

```text
tokensOut = floor((rT + virtualTokenOffset) × n / (V + rQ + n))
```

Output is capped at the remaining sale allocation. A final buy is capped at the remaining quote target and excess payment is refunded or not taken. Solidity integer rounding is authoritative. The SDK's `previewInitialBuy` applies only to a fresh curve; use `quoteBuy` and `quoteSell` on-chain for an existing market.

Fees are deducted before reserve growth: a 1% platform fee plus the configured buy tax. Sell proceeds similarly account for the configured sell tax and platform fee. Tax allocations across creator, burn, holders and liquidity sum to 10,000 basis points.

## Graduation

For BNB, the net target is 18 BNB. Other quote assets freeze the 18-BNB-equivalent target using validated creation-time oracle prices. This is not a permanently fixed USD market-cap target, and later quote-asset exchange-rate movements do not change an existing pool's target.

Progress is `(initialSupply - reserveTokens) / saleAllocation`, capped at 100%. Sells reduce progress. At graduation, 200 million tokens and 98% of the accumulated quote reserve seed the external pool; 2% is added to platform credit. Phantom reserves never enter the external pool. For a BNB launch that reaches its target, this means 17.64 BNB of initial quote liquidity.

The virtual-reserve parameters align the final internal marginal price with the initial external reserve ratio, subject to integer rounding and exceptional donated balances. A standard BNB launch starts at approximately 5.739795918 BNB fully diluted valuation. A fresh 0.1 BNB buy with 3% buy tax plus 1% platform fee moves the marginal price by approximately 3.13%, not a guaranteed tens-of-percent move. Later trades have different effects.

These values were checked against the [FOUR integration documentation](https://four-meme.gitbook.io/four.meme/developer/fourmeme-integration) and its published helper. [FLAP's curve documentation](https://docs.flap.sh/flap/developers/basic-and-mechanism/bonding-curve) describes the same general internal-curve/DEX-migration lifecycle but has its own parameters. POGO does not claim that these platforms share identical implementations.
