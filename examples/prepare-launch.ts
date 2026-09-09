import {
  createPublicClient,
  http,
  isAddress,
  zeroAddress,
  type Address,
} from "viem";
import { bsc } from "viem/chains";
import {
  PogoClient,
  candidate,
  buildCreateTransaction,
} from "../sdk/src/index.js";
const creator = process.env.CREATOR_ADDRESS,
  metadataURI = process.env.METADATA_URI;
if (!creator || !isAddress(creator) || !metadataURI)
  throw Error(
    "Set CREATOR_ADDRESS and METADATA_URI. This example never signs or broadcasts.",
  );
const reader = new PogoClient(
  createPublicClient({
    chain: bsc,
    transport: http(
      process.env.BSC_RPC_URL || "https://bsc-dataseed.bnbchain.org",
    ),
  }),
);
const c = await reader.launchConfiguration();
if (c.creationPaused) throw Error("Creation is paused");
let match;
for (let i = 0n; i < 2000000n; i++) {
  const p = candidate(c.deployer, c.initCodeHash, creator as Address, i);
  if (p.address.toLowerCase().endsWith("6666")) {
    match = p;
    break;
  }
}
if (!match) throw Error("No vanity salt found within the bounded search");
const transaction = buildCreateTransaction(
  {
    name: "Example Token",
    symbol: "EXAMPLE",
    metadataURI,
    salt: match.salt,
    quoteAsset: zeroAddress,
    expectedConfig: c.configHash,
    minTarget: c.quote.target,
    maxTarget: c.quote.target,
    tax: {
      buyBps: 0,
      sellBps: 0,
      recipientBps: 10000,
      burnBps: 0,
      holderBps: 0,
      liquidityBps: 0,
      recipient: creator as Address,
      minimumHolding: 0n,
    },
  },
  c.creationFee,
);
console.log(
  JSON.stringify(
    {
      predictedToken: match.address,
      transaction,
      note: "Unsigned only. Check predicted address availability, refresh configuration, simulate and use your wallet separately.",
    },
    (_, v) => (typeof v === "bigint" ? v.toString() : v),
    2,
  ),
);
