# Protocol architecture

The current factory is `LaunchFactoryV8`, an upgradeable factory with append-only launch templates. Each new project receives a standalone token, curve and revenue vault. For DeFi launches, the standalone mining contract is deployed during graduation, after V2 liquidity is seeded. Before that transaction, the curve and vault report a zero staking-pool address. These project contracts have no upgrade or rescue path.

## Current entrypoints

| Contract | Role |
| --- | --- |
| LaunchFactoryV8 | CREATE2 token creation, template selection, configuration hashes |
| StandardTokenDeployer / StandardLaunchToken | Full ERC-20 deployments, fixed taxes, holder-share synchronization |
| QuoteAssetRegistryV7 | Supported quote assets; independent 6.666 BNB graduation target and original opening reserves |
| DeferredMiningCurveDeployer / DeferredMiningCurve | DeFi curve; deploys mining at graduation and fixes its actual leftover reward budget |
| FixedAllocationMining | Flexible single-token, locked single-token and canonical V2 LP farming |
| DirectedLaunchCurveDeployer | CZ transfer template; remaining tokens transfer to the fixed recipient |
| DeferredMiningVaultDeployer / DeferredMiningRevenueVault | DeFi paired-asset dividends; authenticated, one-time mining-pool binding |
| QuoteVaultDeployer / QuoteRevenueVault | CZ-transfer paired-asset creator revenue and holder dividends |
| BNBQuoteAdapter / BNBTradeRouter | Supported BNB-to-quote routes and BNB trade settlement |

Template 13 uses DeferredMiningCurve (curve version 15), DeferredMiningRevenueVault and FixedAllocationMining (mining version 14). Template 10 uses DirectedLaunchCurve (curve version 9) and QuoteRevenueVault. Both vaults use `DIVIDEND_ASSET_VERSION = 1`. Factory `projectVersion` remains 3: it identifies the multi-asset ABI family, not the economic version. Read the actual project's contracts.

## Graduation and mining activation

Creation and a requested first buy remain one atomic transaction: if the first buy reverts, token creation and its fund transfers revert together. Splitting mining deployment into the later graduation transaction reduces the creation transaction workload without silently omitting the first buy.

At graduation, the curve seeds V2 liquidity, deploys the mining contract through its immutable deployer, binds it to the vault, and activates the actual leftover token budget and canonical LP pair. Any failure reverts the whole graduation transaction. The reward tokens remain in the curve and are released only through the bound mining contract. Neither the budget nor the mining-pool address can be reset afterward.

## Tax lifecycle

Curve trades collect project taxes directly in the paired asset. DEX trades collect token transfer taxes, which are queued in the revenue vault without swapping inside PancakeSwap's pair lock. A permissionless maintenance transaction converts bounded batches to the paired asset and allocates the received amount to the configured destinations. Creator and holder ledgers never credit the launched token in the new vault.

Creator payments are attempted automatically. Reverting recipients retain a claimable credit; retries cannot redirect it. Holder balances use an accumulator with settlement before share changes. Single-token staking preserves beneficial ownership; LP units do not count as token shares. A holder can claim, or any caller can fund `claimFor(holder)` with the payout fixed to that holder.

Optional buyback or liquidity processing runs in an isolated subcall: failure cannot roll back completed dividend conversion. Failed tax conversion reverts its own accounting and leaves pending tokens available. No caller can choose an arbitrary swap route or spend credited dividends.

## Source organization

Current production entrypoints are grouped by function in `contracts/src`. Required inheritance, compatibility implementations and test dependencies are in `contracts/internal`. The [contract directory guide](../contracts/README.md) identifies each current file and links to the original verification layout. Solidity contract names are retained, but release-number directories are no longer used. Superseded snapshots remain in Git history; build outputs, private journals and secrets are excluded.
