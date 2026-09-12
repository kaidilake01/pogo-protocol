# Changelog

## 2026-09-12 — Paired-asset dividends and DeFi templates

- Creator revenue and holder dividends settle in the paired asset for templates 9 and 10.
- Preserve .01 BNB test graduation, original opening reserves, 90 occupied-day rewards and 24-hour locks.
- Early-exit single-token/LP deductions go to dEaD; LP liquidity remains in its V2 pair.
- Refresh SDK template transactions, public addresses and source checksums.
- Remove unused Solidity snapshots, obsolete ABI modules and unreferenced old tests.

## 0.1.0 — 2026-09-09

Initial public source release.

- Standard standalone token, curve and vault contracts, with inherited legacy dependencies.
- TypeScript SDK with contract ABIs, configuration readers and unsigned transaction builders.
- English architecture, economics, integration, indexing and automation documentation.
- Public deployment snapshot, deterministic Solidity tests and SDK regression tests.
- CI, contribution templates and dependency-update configuration.

This source release does not upgrade any deployed contract or publish an npm package.
