# Testing and reproducibility

Run `npm ci`, `npm run build`, `npm run typecheck`, `npm test`, `forge test` and `npm run check:manifest` from the public repository. Solidity is 0.8.28 with optimizer 200, via IR and Paris EVM.

Selected regressions cover quote-only native and six-decimal payouts, rejection of token-asset claims, recipient failures and retry, optional LP/buyback failure isolation, third-party claims without payout redirection, staking eligibility, reward accounting and early-exit conservation. The shared fixture deploys the current factory, template 13, fixed-allocation mining version 14, a vault that binds its mining contract at graduation, and the 6.666 BNB target. Vault-binding regressions cover unauthorized and mismatched pools, duplicate binding, counterfactual address holder balances and preservation of prior dividend credits. Superseded implementation tests are not part of this source snapshot.

`DeferredMiningForkTest` uses the active template 13 and actual BSC PancakeSwap contracts for BNB and PEPE launches with 0%, 3% and 5% project tax. It checks atomic creation plus first buy, the delayed mining deployment, graduation, external trading, paired-asset revenue, fixed-budget pools, early-exit deductions and LP addition/removal. Its rollback regression requires a rejected first buy to leave no registered token or deployed token code. These cases do not cover every non-BNB quote route or browser wallet. Enable explicitly:

```sh
RUN_BSC_FORK=1 BSC_RPC_URL=https://your-archive-rpc forge test --match-contract DeferredMiningForkTest -vv
```

Use an RPC with historical state support. A skipped fork test is not evidence of a successful integration test. Fork funding and impersonation do not spend real assets. Local and fork checks are engineering validation, not an independent audit.

`docs/source-manifest.json` lists entrypoints and SHA-256 checksums for every shipped Solidity file. `check:manifest` also rejects unused production sources and validates four v15 build artifacts against the executable fingerprints in `docs/runtime-manifest.json`, recorded from the mainnet deployment compiler output. Compile with `forge test` or `npm run build:contracts` before running it. The check validates compiler settings and immutable layouts, excludes the outer Solidity metadata footer, and masks only declared immutable values and embedded child metadata IPFS digests. Reorganized source paths change metadata hashes; executable instructions must still match. Regression tests require code changes and malformed metadata to fail this validation.

Generated ABI modules are derived from the same compilation artifacts. No private deployment keys, signed transaction journals or runtime state are shipped.
