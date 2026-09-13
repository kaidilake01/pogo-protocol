# Testing and reproducibility

Run `npm ci`, `npm run build`, `npm run typecheck`, `npm test`, `forge test` and `npm run check:manifest` from the public repository. Solidity is 0.8.28 with optimizer 200, via IR and Paris EVM.

Selected regressions cover quote-only native and six-decimal payouts, rejection of token-asset claims, recipient failures and retry, optional LP/buyback failure isolation, third-party claims without payout redirection, staking eligibility, reward accounting and early-exit conservation. The shared fixture deploys the current factory, template 12, fixed-allocation mining version 14, paired-asset revenue vault, and 6.666 BNB target. Superseded implementation tests are not part of this source snapshot.

`FixedAllocationForkTest` uses actual BSC PancakeSwap V2 contracts for BNB launches with zero and nonzero project tax. It exercises graduation, external trading, paired-asset revenue, the three fixed-budget pools, early-exit deductions, and LP addition/removal. This shipped fork test does not claim coverage of every non-BNB quote route. Enable explicitly:

```sh
RUN_BSC_FORK=1 BSC_RPC_URL=https://your-archive-rpc forge test --match-contract FixedAllocationForkTest -vv
```

Use an RPC with historical state support. A skipped fork test is not evidence of a successful integration test. Fork funding and impersonation do not spend real assets. Local and fork checks are engineering validation, not an independent audit.

`docs/source-manifest.json` lists selected entrypoints and SHA-256 checksums for shipped Solidity files. Generated ABI modules are derived from the same compilation artifacts. No private deployment keys, signed transaction journals or runtime state are shipped.
