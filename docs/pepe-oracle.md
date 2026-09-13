# PEPE quote feed

PEPE on BNB Chain: `0x25d887Ce7a35172C62FeBFD67a1856F20FaEbB00`.

The current adapter uses a Pancake V3 30-minute TWAP and BNB/USD. The pool oracle extends accumulators across idle blocks: a pool does not need a recent swap to calculate the current window. Insufficient history, low active/harmonic liquidity, excessive spot/TWAP deviation, and stale or invalid BNB/USD rounds still reject the quote. The returned timestamp preserves the BNB/USD round timestamp.

This fixes launch rejection after 30 minutes without a new pool observation. It does not guarantee that a local DEX price matches every exchange. The feed is read-only and receives no user assets.

Tests cover idle periods and unchanged rejection checks. The current optional fork suite covers the PEPE route with 0%, 3% and 5% project taxes, atomic creation plus first buy, graduation, V2 trades and mining. Hosted availability and executable quotes must be checked before submitting a new launch; a passing contract simulation is not a completed user-wallet transaction.
