<p align="center">
  <img src="assets/pogo-mark.svg" width="96" alt="POGO" />
</p>

<h1 align="center">POGO Protocol</h1>

<p align="center">Multi-asset token launches on BNB Chain</p>

<p align="center">
  <a href="https://github.com/kaidilake01/pogo-protocol/actions/workflows/ci.yml"><img src="https://github.com/kaidilake01/pogo-protocol/actions/workflows/ci.yml/badge.svg" alt="Protocol checks" /></a>
  <a href="LICENSE"><img src="https://img.shields.io/badge/license-MIT-aee58b" alt="MIT license" /></a>
  <img src="https://img.shields.io/badge/Solidity-0.8.28-363636" alt="Solidity 0.8.28" />
  <img src="https://img.shields.io/badge/network-BNB%20Chain-F0B90B" alt="BNB Chain" />
</p>

<p align="center">
  <a href="docs/README.md">Documentation</a> ·
  <a href="sdk/README.md">SDK</a> ·
  <a href="examples/README.md">Examples</a> ·
  <a href="CONTRIBUTING.md">Contributing</a> ·
  <a href="SECURITY.md">Security</a>
</p>

Smart contracts, a TypeScript SDK, and developer documentation for POGO on BNB Chain.

POGO launches tokens against a supported quote asset, trades them on an internal bonding curve, and migrates completed markets to PancakeSwap V2. Traders can use BNB for supported non-BNB quote assets, including PEPE, through an on-chain conversion route.

This repository contains the protocol source snapshot and a source-distributed SDK. It does not include the hosted website, production credentials, databases, private deployment journals, or a claim of an independent security audit. The SDK is not published to npm by this release.

## Repository layout

```text
contracts/src/       Current production contracts, organized by function
contracts/internal/ Required implementation dependencies, not launch alternatives
sdk/                 TypeScript readers, ABIs, math and unsigned transaction builders
tests/contracts/     Deterministic Solidity tests and fuzz tests
tests/sdk/           SDK regression tests
examples/            Read-only and transaction-preparation examples
docs/                Architecture, economics, integration and public deployments
scripts/             Public source-manifest validation
```

## Quick start

Requirements: Node.js 22 or newer, npm, and [Foundry](https://getfoundry.sh/).

```sh
git clone https://github.com/kaidilake01/pogo-protocol.git
cd pogo-protocol
npm ci
npm run build
npm run typecheck
npm test
npm run test:contracts
npm run check:manifest
```

Read live BSC configuration without signing or spending funds:

```sh
npm run example:read
```

The examples accept `BSC_RPC_URL` for an optional RPC endpoint. They never load a private key or broadcast a transaction.

## Current launch model

| Parameter | Current templates |
| --- | --- |
| Supply | 1 billion tokens |
| Templates | DeFi staking & liquidity mining (11); CZ transfer (10) |
| Current graduation target | 0.01 BNB equivalent for testing |
| Opening reserves | Preserved independently of the graduation target |
| Creator revenue / holder dividends | Paired asset on both curve and DEX |
| Mining reward allocation | 6.25% flexible / 31.25% locked single / 62.5% V2 LP (fixed reward budgets) |
| Reward duration | 90 occupied days per pool; empty pools pause |
| Locks | 24 hours per deposit; 10% early-exit principal deduction |
| Early-exit destination | Single tokens and LP receipts to dEaD |
| Creation charge | Zero, plus wallet transaction gas |

DEX tax tokens are automatically converted before distribution; beneficiaries receive the paired asset directly. Existing immutable projects retain their original rules. [Read the full economics](docs/economics.md).

The factory is upgradeable. Newly launched standard tokens, curves, and vaults use full standalone deployments. Required inherited implementations live in `contracts/internal/`; they are dependencies, not alternative launch templates. Existing projects retain their deployment-time terms.

An off-chain caller is required to submit graduation and maintenance transactions. The hosted keeper does this automatically when execution conditions and gas limits permit; smart contracts do not wake up on a timer.

## Developer documentation

- [Architecture and permissions](docs/architecture.md)
- [Bonding-curve economics](docs/economics.md)
- [SDK and wallet integration](docs/integration.md)
- [Events and market-data indexing](docs/indexing.md)
- [Automation and revenue](docs/automation.md)
- [Public BSC deployment snapshot](docs/deployments.md)
- [Testing and reproducibility](docs/testing.md)
- [Contribution guidelines](CONTRIBUTING.md)
- [Security policy](SECURITY.md)

## License

MIT. See [LICENSE](LICENSE) and [third-party notices](THIRD_PARTY_NOTICES.md).
