# Protocol architecture

The current factory is `LaunchFactoryV8`, an upgradeable factory with append-only launch templates. Each new project receives a standalone token, curve and revenue vault. DeFi launches also receive a standalone mining contract. These project contracts have no upgrade or rescue path.

## Current entrypoints

| Contract | Role |
| --- | --- |
| LaunchFactoryV8 | CREATE2 token creation, template selection, configuration hashes |
| StandardTokenDeployer / StandardLaunchToken | Full ERC-20 deployments, fixed taxes, holder-share synchronization |
| QuoteAssetRegistryV7 | Supported quote assets; independent 0.01 BNB test target and original opening reserves |
| ReflowCurveDeployer / ReflowCurve | DeFi curve, graduation and actual leftover reward funding |
| FixedAllocationMining | Flexible single-token, locked single-token and canonical V2 LP farming |
| DirectedLaunchCurveDeployer | CZ transfer template; remaining tokens transfer to the fixed recipient |
| QuoteVaultDeployer / QuoteRevenueVault | Paired-asset-only creator revenue and holder dividends |
| BNBQuoteAdapter / BNBTradeRouter | Supported BNB-to-quote routes and BNB trade settlement |

Template 11 uses ReflowCurve (curve version 11) with FixedAllocationMining (mining version 13); template 10 uses DirectedLaunchCurve (curve version 9). Both use QuoteRevenueVault (`DIVIDEND_ASSET_VERSION = 1`). Factory `projectVersion` remains 3: it identifies the multi-asset ABI family, not the economic version. Read the actual project's contracts.

## Tax lifecycle

Curve trades collect project taxes directly in the paired asset. DEX trades collect token transfer taxes, which are queued in the revenue vault without swapping inside PancakeSwap's pair lock. A permissionless maintenance transaction converts bounded batches to the paired asset and allocates the received amount to the configured destinations. Creator and holder ledgers never credit the launched token in the new vault.

Creator payments are attempted automatically. Reverting recipients retain a claimable credit; retries cannot redirect it. Holder balances use an accumulator with settlement before share changes. Single-token staking preserves beneficial ownership; LP units do not count as token shares. A holder can claim, or any caller can fund `claimFor(holder)` with the payout fixed to that holder.

Optional buyback or liquidity processing runs in an isolated subcall: failure cannot roll back completed dividend conversion. Failed tax conversion reverts its own accounting and leaves pending tokens available. No caller can choose an arbitrary swap route or spend credited dividends.

## Source organization

Only current production entrypoints, their transitive imports, and the selected regression tests' dependencies are included. Versioned paths still imported by the current factory are dependencies, not alternative launch recommendations. Deleting them would break compilation or alter verification metadata. Superseded snapshots remain in Git history; build outputs, private journals and secrets are excluded.
