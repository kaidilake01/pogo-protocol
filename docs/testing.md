# Testing and reproducibility

## Release validation — September 9, 2026

- Solidity: 134 tests passed, 0 failed, 1 optional live-RPC test skipped; fuzz tests used 256 runs per case.
- SDK: 8 tests passed; package build and TypeScript checks passed.
- The read-only example successfully resolved the live BSC factory's version-5 configuration and 18-BNB native graduation target.
- The Solidity source SHA-256 manifest passed verification. These results apply to this release snapshot, not future commits or subsequent mainnet changes.

## Reproducing the checks

Install dependencies with `npm ci`. `npm run test:contracts` runs deterministic Solidity tests and fuzz cases with Solidity 0.8.28, Paris EVM, optimizer 200 and via-IR. `npm test` checks SDK arithmetic, input validation and transaction encoding. `npm run typecheck` checks the SDK, tests and examples; `npm run build` emits the SDK package.

The test tree includes legacy fixture dependencies and regression suites. None of the included default tests submits a mainnet transaction. Production deployment/signing scripts are deliberately excluded. Fork tests tied to previous live deployment assumptions are not shipped as default tests.

`StandardCurve.t.sol` covers initial price, taxed trading, virtual reserves, sale allocation, delayed pair deployment, graduation liquidity, and invariant-style sequences. These tests improve reproducibility but do not replace an independent audit.

For a fork integration, pin a BSC block and use impersonation or local test accounts only. Verify create-only and create-plus-buy for each supported quote asset, an internal sell, graduation against the real DEX, LP destination and post-graduation buy/sell. Never reuse a production key for a fork test. Oracle freshness checks use block time, so retain a consistent fork clock.
