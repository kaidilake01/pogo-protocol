# Launch and mining economics

## Current test deployment

| Parameter | Value |
| --- | --- |
| Initial supply | 1 billion tokens, 18 decimals |
| Creation charge | Zero; transaction gas remains payable |
| Net graduation target | 0.01 BNB equivalent, fixed in quote-asset units at creation |
| Production design benchmark | 6.666 BNB; not the current test target |
| Opening virtual BNB reserve | ceil(18 × 25 / 73) BNB |
| Opening virtual token reserve | ceil(800 million × 98 / 73) tokens |
| Project buy/sell taxes | Independently 0–5% |
| Graduation seeding fee | 2% of net quote reserve |
| External market | PancakeSwap V2 |

Reducing the graduation target does not scale down opening virtual reserves. With virtual quote Q, virtual tokens T and net graduation target G, the sale amount is floor(T×G/(Q+G)). Graduation quotes are G less the seeding fee; liquidity tokens are calculated at the graduation price. The actual remaining token balance goes to mining or the CZ transfer destination according to the selected template. At the 0.01 BNB test target, the remainder is about 996.56 million tokens; it is not fixed at 180 million.

CZ transfer is an ordinary transfer to `0x28816c4C4792467390C90e5B426F198570E29307`, preserving total supply. It is not a burn, a lock or an endorsement. The recipient can transfer the tokens and receives holder dividends if eligible.

## DeFi mining

| Pool | Share of actual reward budget | Principal lock |
| --- | --- | --- |
| Flexible single token | 1% | None |
| Locked single token | 9% | 24 hours per deposit |
| Canonical V2 LP | 90% | 24 hours per deposit |

Each pool consumes 90 occupied days of release time. Its clock pauses while nobody is staked; it neither burns empty-pool rewards nor emits them as a catch-up windfall. APR varies with reward rates and staked value. Rewards are the launched token; tax dividends are the paired asset. These are different revenue mechanisms.

Before the 24-hour unlock, early principal withdrawal deducts 10%. Single-token deductions transfer to dEaD, preserving token totalSupply. LP deductions transfer the LP receipt to dEaD, permanently locking the corresponding liquidity in the V2 pool; they do not call pair.burn or remove underlying liquidity. Mature withdrawals and flexible withdrawals have no early-exit deduction. Historical pools retain their original rules.
