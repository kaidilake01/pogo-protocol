# Current contracts

Start in [`src/`](src). This directory contains the current production entrypoints, organized by function rather than release number.

| File | Purpose |
| --- | --- |
| [LaunchFactory.sol](src/LaunchFactory.sol) | Factory and launch-template registration |
| [QuoteAssetRegistry.sol](src/QuoteAssetRegistry.sol) | Quote-asset configuration and graduation target |
| [LaunchToken.sol](src/LaunchToken.sol) | Current launch token |
| [TokenDeployer.sol](src/TokenDeployer.sol) | Standalone token deployment |
| [MiningCurve.sol](src/MiningCurve.sol) | DeFi launch curve and V2 graduation |
| [MiningCurveDeployer.sol](src/MiningCurveDeployer.sol) | DeFi curve deployment |
| [Mining.sol](src/Mining.sol) | Fixed 6.25% / 31.25% / 62.5% mining budgets |
| [RevenueVault.sol](src/RevenueVault.sol) | Creator revenue and holder dividends in the paired asset |
| [TransferCurve.sol](src/TransferCurve.sol) | CZ-transfer launch curve |
| [TransferCurveDeployer.sol](src/TransferCurveDeployer.sol) | CZ-transfer curve deployment |
| [BNBQuoteAdapter.sol](src/BNBQuoteAdapter.sol) | BNB conversion for quote-asset launches |
| [BNBTradeRouter.sol](src/BNBTradeRouter.sol) | BNB conversion for trading |

[`internal/`](internal) contains only dependencies reached by these contracts or their retained regression tests. They include the factory's inheritance chain, shared types, and ABI compatibility implementations. They are not additional templates to deploy. Removing inherited factory bases would remove storage fields and methods that the current factory still uses.

Solidity contract names and version constants are retained for ABI compatibility and identification. This reorganization changes relative import paths only; it does not deploy contracts or change chain state. File paths affect Solidity verification metadata. The original deployment-time layout is available in [the source snapshot before reorganization](https://github.com/kaidilake01/pogo-protocol/tree/93dab90b3d73b036a77dc563570fe88a60a3cfe9/contracts/src); use the explorer-verified source or that snapshot when reproducing historical verification inputs.
