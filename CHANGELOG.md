# Current release

## 2026-09-13 · BSC mainnet

- Graduation target: **6.666 BNB equivalent net reserves**; opening virtual reserves are unchanged.
- Current templates: **13** for DeFi mining and **10** for CZ transfer.
- DeFi curve version 15 deploys mining during graduation; token creation and a requested first buy remain atomic.
- Mining budgets: **4% flexible / 16% locked single-token / 80% V2 LP**. Each pool releases over 90 occupied days and distributes by stake share.
- Locks: 24 hours; early exits transfer 10% of withdrawn principal to the burn address. The platform does not receive the deduction.
- Creator revenue and holder dividends use the paired asset; mining pays project tokens.
- Source tree contains current production entrypoints and their required dependencies. Superseded standalone implementations and obsolete tests have been removed.
- Current documentation explains token creation, reserve pricing and graduation with a concise flow diagram.

See [current rules](docs/current-rules.json) and [deployment record](docs/deployments/deferred-mining.json). Existing deployed projects retain their own fixed parameters.
