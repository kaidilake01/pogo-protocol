# Automation and revenue

Contracts require transactions to execute. The hosted keeper periodically inspects factory-registered markets and can call permissionless maintenance methods. A public deployment of these contracts must provide its own caller or keeper; the hosted POGO service is not a dependency supplied by this repository.

- `graduate()` is executable after the curve reaches its immutable target. It creates/funds the external pair and sends LP to the dead address.
- `claimPlatform()` sends accrued platform credit to the configured treasury. The factory exposes its own creation-fee claim.
- `distributeFees()` processes accumulated external token taxes through the token/vault mechanism.
- `runAutomation()` processes eligible buyback and liquidity budgets using contract-enforced limits.

The buyback minimum is `pool.virtualQuote() / 10,000` in raw quote units. Internal buybacks have a 30-second minimum interval and need an executable curve quote. For a standard BNB curve the minimum is approximately 0.00061644 BNB. External processing additionally uses a 180-second cumulative-price observation, a 1% spot-deviation limit and bounded execution sizes. A threshold crossing does not guarantee immediate execution.

Creator allocation is attempted automatically; failed recipient transfers become claimable credit rather than blocking trades. Holder accounting is balance-based; holders claim the applicable assets, subject to the configured minimum holding and eligibility rules. These assets and platform/creator credits are separate from buyback budgets.

An operator should simulate each action, cap gas spending, journal pending transactions, wait for receipts and retry transient failures without signing duplicate transactions blindly. Never place a live keeper signing key in this repository.
