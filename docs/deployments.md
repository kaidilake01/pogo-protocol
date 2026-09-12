# Public BSC deployment

The machine-readable [snapshot](deployments/bsc-mainnet.json) and SDK constants describe the September 12, 2026 paired-asset revenue release.

| Setting | Current value |
| --- | --- |
| Factory proxy | `0x0abc6174ee9f9600243D14F83E215993b8BbABEb` |
| Factory implementation | `0xc8C820a3DEc5666E9a4B02275E293a6f15f4b813` |
| QuoteVaultDeployer | `0xD8FeFE95d325c918a4c7E2754967567E41922cc3` |
| Default DeFi template | 9 |
| CZ transfer template | 10 (displayed last) |
| Graduation test target | 0.01 BNB equivalent |

Both enabled templates deploy the paired-asset-only vault. Template registration preserves old projects and their addresses. Old template IDs are disabled for new launches. Refresh `launchTemplates`, `templateConfigHash` and quote targets on-chain before signing; this file is a dated snapshot.

The factory implementation, opening reserves, .01 target, mining split, 24-hour locks and dEaD early-exit rules were preserved by the revenue release. The hosted verifier submits the new deployer and newly created standalone vaults for explorer source verification. Verification proves source/bytecode correspondence, not a security audit.
