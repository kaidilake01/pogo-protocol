# SDK and wallet integration

The SDK is supplied in `sdk/`; this release does not publish an npm package. Run `npm ci && npm run build` from the repository root. See the [SDK reference](../sdk/README.md) and [examples](../examples/README.md).

## Read before preparing a transaction

Use BSC chain ID 56. Read `launchConfiguration(quoteAsset, templateId)` immediately before preparing a launch. It resolves the current registry and token deployment data through the factory. The returned config hash and target bounds protect against changed configuration and oracle-driven target movement. A stale quote must be refreshed, not silently submitted with zero minimums.

Creation-only requires the on-chain creation fee. Creation plus a native first buy requires that fee plus the gross input. ERC-20-funded creation requires the appropriate factory allowance. Quote amounts use the selected asset's decimals; launch tokens always use 18 decimals. Never use JavaScript floating-point arithmetic for transaction amounts.

The transaction builders return `{to, data, value}` only. They do not connect a wallet, request approvals, estimate fees, sign, or broadcast. Simulate using the user's account, then let a wallet estimate current gas and confirm the transaction. A successful simulation is not a receipt. Handle rejected signatures, replaced transactions, mined reverts, and confirmed successes separately.

## BNB and non-BNB quote assets

Use the curve directly for native-BNB markets. For supported non-BNB markets, including PEPE, route BNB through `BNBTradeRouter` and a supported `BNBQuoteAdapter.Route`. Obtain executable quotes from the relevant DEX quoter and validate route endpoints. The SDK does not bundle a hosted quote API or a route discovery service.

For internal routed sells, approve the pool as required by `sellFor`; for external routed sells, the router receives tokens and needs the corresponding allowance. For direct ERC-20 buys and direct token sells, approve the curve. Bound approvals to the intended amount where practical.

## Compatibility

`projectVersion(token)` remains 3 for the multi-asset factory ABI family, while `pool.VERSION()` is 15 for DeFi and 9 for CZ transfer. These are different version axes. Do not infer economics from the project ABI version alone. Required compatibility types live in `contracts/internal/`. Select new launches through the current registered templates.

## Template selection

The launch readers and unsigned creation builders default to template 13. Pass template 10 for CZ transfer. Creation builders accept `templateId` after the optional factory address. They encode `createTokenWithTemplateV8` or `createTokenAndBuyWithTemplateV8`, and the launch config hash must come from the same template. The current `vaultAbi` represents `DeferredMiningRevenueVault`; `transferVaultAbi` represents the CZ-transfer `QuoteRevenueVault`, and `miningAbi` represents `FixedAllocationMining`. Do not use project TOKEN as the dividend asset in a quote-only vault.

## Deferred mining and wallet providers

For a version-15 DeFi curve, `stakingPool()` is zero before graduation. Re-read it after a confirmed `GraduationV3` / `MiningFunded` transaction and then read `FixedAllocationMining.VERSION()` and its budgets. Do not cache the zero address permanently or infer a pool address from another project.

Use the selected extension’s EIP-6963/EIP-1193 provider consistently for account checks, chain switching and transaction requests. Do not replace it with whichever wallet last wrote `window.ethereum`. Simulate the exact creation calldata and native value, estimate its gas, and respect the chain’s transaction gas cap. A returned wallet hash alone is not confirmation: verify the successful receipt, factory creation event and first-buy transfer to the intended buyer. Automated contract and provider tests do not establish that every wallet product or release has been tested.
