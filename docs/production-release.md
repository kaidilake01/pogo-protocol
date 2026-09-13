# BSC mainnet launch configuration

New launches graduate at **6.666 BNB equivalent in net paired-asset reserves**. For non-BNB assets, the token quantity is quoted and fixed at creation. Trading fees, project taxes and conversion costs are additional to the reserve target.

Opening virtual reserves are unchanged. Creation has no platform charge; network gas applies. The enabled templates are 10 (CZ transfer) and 13 (DeFi mining). The DeFi token, curve and vault are deployed at creation; its mining contract is deployed and activated at graduation. Mining receives actual graduation leftovers and assigns 4% to flexible staking, 16% to locked single-token staking and 80% to V2 LP staking. Each pool releases over 90 occupied days; rewards within a pool follow stake share. Lock periods are 24 hours; early-exit principal deductions of 10% go to the burn address, not the platform.

The factory registered the new DeFi curve and vault as template 13 and disabled the previous DeFi template for new launches. The existing registry, factory implementation and template 10 were retained. Existing projects retain their original launch terms and rewards. Public configuration and SDK snapshots reflect the active selection.

Release validation includes deterministic reward-accounting and vault-binding tests. The optional BSC mainnet-fork suite exercises atomic creation plus first buy, graduation, V2 trading, revenue conversion, three-pool staking, claiming, early exits and liquidity removal for BNB and PEPE routes at 0%, 3% and 5% project tax rates. A failing first buy must roll back creation and allow the same unused salt to be retried. These tests are not an independent security audit, a traffic-capacity guarantee or a claim that every wallet extension has been exercised.

The [deployment receipt](deployments/deferred-mining.json) records addresses, transactions and gas. The [current rules](current-rules.json) are shared with the website.
