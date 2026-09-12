# POGO TypeScript SDK

Source-distributed SDK for the multi-asset POGO protocol on BSC. This repository release does not publish the package to npm. Build it with `npm ci && npm run build` from the repository root. Consumers may pack the workspace locally using `npm pack --workspace=pogo-protocol-sdk` after building.

```ts
import {createPublicClient, http} from 'viem';
import {bsc} from 'viem/chains';
import {PogoClient} from 'pogo-protocol-sdk';

const client = new PogoClient(createPublicClient({chain: bsc, transport: http()}));
const configuration = await client.launchConfiguration();
console.log(configuration.quote.target);
```

| Export | Purpose |
| --- | --- |
| `PogoClient.launchConfiguration(asset)` | Fresh registry quote, creation fee, config hash and deployment configuration |
| `PogoClient.project(token)` | Factory-registered creator, curve, vault and creation time |
| `PogoClient.market(token)` | Internal curve state and graduation flag; after graduation, query the DEX pair for current external price |
| `PogoClient.quoteBuy(pool, amount)` | Contract quote at current state |
| `PogoClient.quoteSell(pool, amount)` | Contract sell quote at current state |
| `candidate` / `predictToken` | Creator-bound standalone CREATE2 prediction |
| `validateTax` / `validateLaunch` | Basic client-side validation; simulation is still required |
| `buildCreateTransaction` | Unsigned create-only call |
| `buildCreateAndBuyTransaction` | Unsigned atomic creation and first buy |
| `buildCurveBuy` / `buildCurveSell` | Unsigned direct internal trades |
| `buildBNBBuy` | Unsigned BNB-routed buy for a non-native quote market |
| `buildGraduation` | Unsigned permissionless graduation call |
| `previewInitialBuy` | Fresh-curve integer preview; explicitly pass the curve version |
| `factoryAbi`, `curveAbi`, `tokenAbi`, `vaultAbi`, `registryAbi`, `bnbRouterAbi`, `adapterAbi` | Contract interfaces, including events and errors |

Amounts are `bigint` in raw token units. Deadlines are Unix seconds. Builders never estimate gas, approve assets, sign, broadcast, or ensure a route is currently liquid. Validate and simulate against fresh on-chain state. `previewInitialBuy` defaults to legacy version 3 for compatibility; pass `Number(configuration.curveVersion)` for standard launches.

The package includes a dated public deployment snapshot. Resolve mutable configuration through the factory. Use this SDK for the multi-asset ABI family; the oldest single-asset V2 project interfaces are available in Solidity sources but not wrapped by `PogoClient`.

## Current templates

Default template ID is 11 (DeFi); ID 10 is CZ transfer. `launchConfiguration(quoteAsset, templateId)` reads the matching hash. Pass the same ID as the fourth argument of `buildCreateTransaction` or the fifth argument of `buildCreateAndBuyTransaction` after the factory address. Vault and mining ABIs are exported as `vaultAbi` and `miningAbi`. Historical project rewards must use that project’s original ABI and asset.
