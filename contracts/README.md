# Current contracts

Start in [`src/`](src). This directory contains the current production entrypoints, organized by function rather than release number.

| File | Purpose |
| --- | --- |
| [LaunchFactory.sol](src/LaunchFactory.sol) | Factory and launch-template registration |
| [QuoteAssetRegistry.sol](src/QuoteAssetRegistry.sol) | Quote-asset configuration and graduation target |
| [LaunchToken.sol](src/LaunchToken.sol) | Current launch token |
| [TokenDeployer.sol](src/TokenDeployer.sol) | Standalone token deployment |
| [MiningCurve.sol](src/MiningCurve.sol) | DeFi curve; creates the mining pool during V2 graduation |
| [MiningCurveDeployer.sol](src/MiningCurveDeployer.sol) | DeFi curve deployment |
| [Mining.sol](src/Mining.sol) | Fixed 4% / 16% / 80% mining budgets |
| [MiningRevenueVault.sol](src/MiningRevenueVault.sol) | DeFi paired-asset dividends; binds the mining pool once at graduation |
| [RevenueVault.sol](src/RevenueVault.sol) | CZ-transfer paired-asset creator revenue and holder dividends |
| [TransferCurve.sol](src/TransferCurve.sol) | CZ-transfer launch curve |
| [TransferCurveDeployer.sol](src/TransferCurveDeployer.sol) | CZ-transfer curve deployment |
| [BNBQuoteAdapter.sol](src/BNBQuoteAdapter.sol) | BNB conversion for quote-asset launches |
| [BNBTradeRouter.sol](src/BNBTradeRouter.sol) | BNB conversion for trading |

[`internal/`](internal) contains only dependencies reached by these contracts. They include the factory's inheritance chain, shared types, and ABI compatibility implementations. They are not additional templates to deploy. Removing inherited factory bases would remove storage fields and methods that the current factory still uses.

Solidity contract names and version constants are retained for ABI compatibility and identification. File paths affect Solidity verification metadata. For deployed bytecode verification, use the compiler input published by the block explorer for the address in the [current deployment snapshot](../docs/deployments/bsc-mainnet.json).
