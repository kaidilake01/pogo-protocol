# Examples

Run from the repository root after `npm ci`.

```sh
npm run example:read
npm run example:read -- <YOUR_LAUNCHED_TOKEN_ADDRESS>
```

The second command reads a historical project. Its curve version and economics may differ from a new standard launch.

To prepare an unsigned creation request in PowerShell:

```powershell
$env:CREATOR_ADDRESS = "YOUR_PUBLIC_WALLET_ADDRESS"
$env:METADATA_URI = "ipfs://YOUR_PINNED_METADATA_CID"
npm run example:create
```

Replace both placeholders with real values. Optionally set `BSC_RPC_URL`. This example searches a bounded vanity salt range, reads configuration and prints an unsigned request. It never uploads metadata, loads a private key or sends a transaction. Check that the predicted address is unused and simulate with the actual sender before asking a wallet to submit it.
