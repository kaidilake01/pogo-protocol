# Architecture and permissions

## Contracts

| Contract | Responsibility |
| --- | --- |
| `LaunchFactoryV5` | UUPS factory upgrade and coordinated registry/deployer configuration |
| `LaunchFactoryV3` / `LaunchFactoryV4` | Inherited creation, registry, BNB conversion and standalone deployment logic |
| `QuoteAssetRegistryV3` | Supported quote assets, oracle validation, version-5 launch parameters |
| `StandardTokenDeployer` | CREATE2 full-runtime token deployment |
| `StandardCurveDeployer` | Full-runtime version-5 market deployment |
| `StandaloneVaultDeployer` | Full-runtime per-token revenue vault deployment |
| `StandardLaunchToken` | Fixed-supply ERC-20, immutable launch relationship and tax parameters |
| `StandardCurve` | Internal buys/sells, reserve accounting and graduation |
| `RevenueVault` | Creator allocation, holder accounting, buyback and liquidity budgets |
| `BNBQuoteAdapter` / `BNBTradeRouter` | BNB conversion and routed trades |

## Launch lifecycle

1. Read the factory's current registry, creation fee, deployment configuration and launch configuration hash.
2. Read the quote asset's current launch quote. Pin immutable metadata separately.
3. Search a creator-bound CREATE2 salt whose predicted token address ends in `6666`.
4. Simulate `createTokenV3` or `createTokenAndBuyV3`, then submit through the user's wallet.
5. Trade against the internal curve. The launch transaction reserves the canonical external pair address but does not deploy that pair. Transfers to that destination are blocked before activation.
6. When the net reserve reaches the target, a caller invokes `graduate()`. It creates or uses the canonical empty PancakeSwap pair, deposits the liquidity allocation, and mints LP tokens to the dead address.

BNB-to-quote conversion uses existing liquidity for the **quote asset**, such as WBNB/stock-token. That is distinct from the **new launch-token/quote-asset pool**, which is funded at graduation.

## Authority boundaries

The factory owner can upgrade the factory and change future launch configuration, supported registry/deployers, treasury or creation availability through the exposed owner methods. Quote-registry configuration is owner-controlled. Integrators must resolve current configuration rather than treating addresses in a dated manifest as immutable.

The standard launch token reports a zero owner and has fixed supply; its bound curve and vault have their own constructor/initialization restrictions. Full standalone deployment does not remove protocol-level configuration authority. Existing standalone instances are not automatically rewritten by a factory upgrade.

Keeper entry points are permissionless and constrain destinations in the contracts. Creators may also trigger the creator-authorized buyback method with explicit bounds. Holder payouts require the applicable on-chain claim; do not describe every holder reward as an automatic wallet transfer.
