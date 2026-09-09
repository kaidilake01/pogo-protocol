# Events and market-data indexing

Index confirmed factory `TokenCreatedV3` events, then the corresponding token, curve and vault addresses. Persist block number, block hash, transaction hash and log index. Apply a confirmation policy and roll back derived records on reorgs. Use `(transactionHash, logIndex)` as an idempotency key.

Internal `TradeV3` events contain direction, quote amount, token amount, execution price, resulting quote reserve, platform fee and tax. The event's `price` represents the average execution price of that trade, not the post-trade marginal curve price. If charting marginal price, replay token reserve changes and use the correct virtual token offset. Clearly document the chart convention. Do not manufacture trades or volume to draw a curve.

Keep raw quote units, historical quote/USD conversion, and optional BNB conversion separate. Historical USD candles require the historical oracle value available at the trade block. A new quote registry did not exist at earlier blocks; resolve historical configuration at the relevant block. Do not substitute today's price for a missing historical quote.

At `GraduationV3`, track the emitted pair and index its DEX swap events. Internal history is not automatically available to third-party terminals: they must integrate these events or an indexer. Merely verifying a token on BscScan does not integrate its internal chart with every trading terminal.

Respect RPC range and rate limits, bound concurrency, back off on throttling, and retain the last confirmed checkpoint. A temporary indexing warning should not erase an already loaded token list. Surface delayed synchronization independently from a failed data request.
