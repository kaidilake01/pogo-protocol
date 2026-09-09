# Public deployments

The [BSC manifest](deployments/bsc-mainnet.json) records the standard-v5 deployment snapshot dated 2026-09-09. The factory is a UUPS proxy; the token, curve and vault deployers create standalone instances for new standard launches.

| Component | BSC address |
| --- | --- |
| factory | [`0x0abc6174ee9f9600243D14F83E215993b8BbABEb`](https://bscscan.com/address/0x0abc6174ee9f9600243D14F83E215993b8BbABEb#code) |
| registry | [`0xaa882B7d53eC9d028f877C5c5202ab2faB1EcD46`](https://bscscan.com/address/0xaa882B7d53eC9d028f877C5c5202ab2faB1EcD46#code) |
| implementation | [`0xd40357d11bf6239Cf2761b487C8C84245B465f34`](https://bscscan.com/address/0xd40357d11bf6239Cf2761b487C8C84245B465f34#code) |
| tokenDeployer | [`0x3e94eE9FFB68Ea159C1DFb2B673C10ce144396Dd`](https://bscscan.com/address/0x3e94eE9FFB68Ea159C1DFb2B673C10ce144396Dd#code) |
| curveDeployer | [`0x5d0dd2197312fe8b86EA142D73c8565a1B7BE01f`](https://bscscan.com/address/0x5d0dd2197312fe8b86EA142D73c8565a1B7BE01f#code) |
| vaultDeployer | [`0x9b905B153Ffadbb5b3BF374C8dA8f1Cae477e78f`](https://bscscan.com/address/0x9b905B153Ffadbb5b3BF374C8dA8f1Cae477e78f#code) |
| bnbAdapter | [`0x8218Bb0A3b3E14600FAAfaEbcb55B5B89BD561bB`](https://bscscan.com/address/0x8218Bb0A3b3E14600FAAfaEbcb55B5B89BD561bB#code) |
| bnbTradeRouter | [`0xAf351493CdA7D60558289d28C3D722331F1c029B`](https://bscscan.com/address/0xAf351493CdA7D60558289d28C3D722331F1c029B#code) |
| pancakeV2Router | [`0x10ED43C718714eb63d5aA57B78B54704E256024E`](https://bscscan.com/address/0x10ED43C718714eb63d5aA57B78B54704E256024E#code) |
| wrappedBNB | [`0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c`](https://bscscan.com/address/0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c#code) |

Resolve current factory configuration and the ERC-1967 implementation slot before integrating. Deployment manifests are historical snapshots, not a guarantee of future configuration.

Verified source is useful for matching bytecode; it is not an independent security audit or a guarantee that third-party terminals will list a token. The `docs/source-manifest.json` file contains SHA-256 hashes of the Solidity snapshot included in this repository.
