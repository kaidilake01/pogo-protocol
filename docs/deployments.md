# Public BSC deployment

The machine-readable [snapshot](deployments/bsc-mainnet.json) and SDK constants describe the September 12, 2026 fixed-allocation mining release, retaining paired-asset creator revenue and holder dividends.

| Setting | Current value |
| --- | --- |
| Factory proxy | `0x0abc6174ee9f9600243D14F83E215993b8BbABEb` |
| Factory implementation | `0xc8C820a3DEc5666E9a4B02275E293a6f15f4b813` |
| QuoteVaultDeployer | `0xD8FeFE95d325c918a4c7E2754967567E41922cc3` |
| FixedAllocationMiningDeployer | `0x97cA4D7458165567e6865942B7e33C78EC1524b8` |
| Mining curve deployer | `0xd6253A2a4475Ca5Be9c025FbCd7932485Ca317cA` |
| Default DeFi template | 11 |
| CZ transfer template | 10 (displayed last) |
| Graduation test target | 0.01 BNB equivalent |

Both enabled templates deploy the paired-asset-only vault. Template registration preserves old projects and their addresses. Old template IDs are disabled for new launches. Refresh `launchTemplates`, `templateConfigHash` and quote targets on-chain before signing; this file is a dated snapshot.

The new mining template fixes reward budgets at 6.25% flexible, 31.25% locked single-token and 62.5% V2 LP. The factory implementation, opening reserves, .01 target, 24-hour locks, paired-asset revenues and dEaD early-exit rules are unchanged. Existing mining pools retain their old allocation. The hosted verifier submits the new deployers and newly created standalone contracts for explorer source verification. Verification proves source/bytecode correspondence, not a security audit.

The [current rules snapshot](current-rules.json) also lists the active template deployers and PEPE price feed used by the website documentation. This dated snapshot is not a substitute for reading live configuration before a transaction.
