import {
  createPublicClient,
  http,
  zeroAddress,
  isAddress,
  type Address,
} from "viem";
import { bsc } from "viem/chains";
import { PogoClient } from "../sdk/src/index.js";
const client = new PogoClient(
  createPublicClient({
    chain: bsc,
    transport: http(
      process.env.BSC_RPC_URL || "https://bsc-dataseed.bnbchain.org",
    ),
  }),
);
const token = process.argv[2];
if (token && !isAddress(token)) throw Error("Expected a token address");
const data = token
  ? await client.market(token as Address)
  : await client.launchConfiguration(zeroAddress);
console.log(
  JSON.stringify(data, (_, v) => (typeof v === "bigint" ? v.toString() : v), 2),
);
