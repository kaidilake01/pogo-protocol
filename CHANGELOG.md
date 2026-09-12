# Current release

## 2026-09-12

- Current launch templates: DeFi mining (11) and CZ transfer (10), with a 0.01 BNB-equivalent net graduation target for testing.
- Fixed DeFi reward budgets: 6.25% flexible, 31.25% locked single token, 62.5% canonical V2 LP. Each pool releases over 90 occupied days and pauses when empty.
- Single-token and LP locks last 24 hours per deposit. Early withdrawals send 10% of withdrawn principal to dEaD; LP receipts remain permanently locked with the underlying liquidity in its V2 pair.
- Creator revenue and holder dividends settle in the paired asset. Mining rewards remain project tokens.
- Production contract entrypoints are organized by function. Only required inherited dependencies remain under `contracts/internal/`.
- Website and developer documentation share a dated rules snapshot. Removed superseded examples, stale deployment links and references to deleted tests.

Earlier releases remain available in [Git history](https://github.com/kaidilake01/pogo-protocol/commits/main/). Updating documentation does not modify existing deployed contracts.
