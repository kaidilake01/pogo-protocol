# BSC mainnet launch configuration

New launches graduate at **6.666 BNB equivalent in net paired-asset reserves**. For non-BNB assets, the token quantity is quoted and fixed at creation. Trading fees, project taxes and conversion costs are additional to the reserve target.

Opening virtual reserves are unchanged. Creation has no platform charge; network gas applies. The enabled templates are 10 (CZ transfer) and 12 (DeFi mining). Mining receives actual graduation leftovers and assigns 4% to flexible staking, 16% to locked single-token staking and 80% to V2 LP staking. Each pool releases over 90 occupied days; rewards within a pool follow stake share. Lock periods are 24 hours; early-exit principal deductions of 10% go to the burn address, not the platform.

The factory selected the new immutable registry atomically. Existing projects retain their original launch terms and rewards. Public configuration and SDK snapshots reflect the current selection.

A BSC mainnet fork verified the target switch, unchanged opening reserves and template records, then taxed and untaxed BNB launches through graduation, V2 trading, revenue conversion, three-pool staking, claiming, early exits and liquidity removal. All enabled registry assets were quoted before the mainnet switch. These checks are release validation, not an independent security audit or a traffic-capacity guarantee.

The [deployment receipt](deployments/production-6666.json) records addresses, transactions and gas. The [current rules](current-rules.json) are shared with the website.
