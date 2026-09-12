# Tax settlement and automation

New creator revenue and holder dividends are denominated only in the project's paired asset. For BNB pairs, recipients receive native BNB; for stock-token pairs, they receive that stock quote token. Mining emissions remain project tokens.

1. Curve trades collect paired-asset taxes and allocate them directly.
2. DEX transfers collect project-token taxes, then queue them in the vault.
3. The keeper calls `runAutomation`. After a minimum three-minute cumulative-price observation, batches of at most 0.25% of token reserves are swapped for the paired asset.
4. The received amount is allocated using the immutable tax shares. Creator payment is attempted; holder rewards become claimable. Users do not sell tokens themselves to receive dividends.

The spot/average deviation limit is 1%, and router minimum output is 99% of the current fee-adjusted estimate. Small budgets accumulate. Price movement or unavailable routes can defer settlement. This is not guaranteed payment on every trade or zero-price-impact conversion. Optional buyback/LP failure is isolated from the completed tax settlement.

This paired-asset settlement follows the general flow described by [FLAP Tax Token V2](https://docs.flap.sh/flap/developers/basic-and-mechanism/flap-tax-token/tax-token-v2.md); POGO uses its own contracts and execution limits, not a byte-for-byte FLAP implementation.

Smart contracts need an external transaction to execute. The hosted keeper discovers projects from the factory and submits graduation, settlement and recipient retry transactions within gas budgets. Anyone can call the permissionless maintenance functions; `claimFor(holder)` always sends to the named holder. Holder self-claims remain available. Keeper downtime does not authorize anyone to take unclaimed funds.

Existing immutable vaults are not upgraded by a template change. Historical project-token credits remain claimable under their original contract, including through the website Account page. The new `validAsset` accepts only the paired asset.
