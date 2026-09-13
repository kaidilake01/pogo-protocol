import {
  encodeFunctionData,
  parseAbi,
  encodeAbiParameters,
  getCreate2Address,
  keccak256,
  isAddress,
  zeroAddress,
  type Address,
  type Hex,
  type PublicClient,
} from "viem";
import {
  factoryAbi,
  curveAbi,
  registryAbi,
  bnbRouterAbi,
} from "./abi/index.js";
import { bscDeployment } from "./deployments.js";
export * from "./abi/index.js";
export * from "./deployments.js";
export * from "./curve-economics.js";
export * from "./launch-quote.js";
export { candidate } from "./vanity.js";

export interface TaxConfiguration {
  buyBps: number;
  sellBps: number;
  recipientBps: number;
  burnBps: number;
  holderBps: number;
  liquidityBps: number;
  recipient: Address;
  minimumHolding: bigint;
}
export interface LaunchParameters {
  name: string;
  symbol: string;
  metadataURI: string;
  salt: Hex;
  quoteAsset: Address;
  expectedConfig: Hex;
  minTarget: bigint;
  maxTarget: bigint;
  tax: TaxConfiguration;
}
export interface SwapRoute {
  kind: number;
  v2Path: readonly Address[];
  v3Path: Hex;
}
export interface DeveloperBuy {
  amount: bigint;
  minQuote: bigint;
  minTokens: bigint;
  deadline: bigint;
  payWithBNB: boolean;
  route: SwapRoute;
}
export type UnsignedTransaction = { to: Address; data: Hex; value: bigint };
export function validateTax(t: TaxConfiguration): void {
  const all = [
    t.buyBps,
    t.sellBps,
    t.recipientBps,
    t.burnBps,
    t.holderBps,
    t.liquidityBps,
  ];
  if (
    all.some((n) => !Number.isInteger(n) || n < 0 || n > 10000) ||
    t.buyBps > 500 ||
    t.sellBps > 500
  )
    throw Error("Invalid tax basis points");
  if (t.recipientBps + t.burnBps + t.holderBps + t.liquidityBps !== 10000)
    throw Error("Tax allocation must total 10000 basis points");
  if (
    !isAddress(t.recipient) ||
    t.recipient.toLowerCase() === zeroAddress ||
    t.minimumHolding < 0n ||
    t.minimumHolding > 10n ** 27n
  )
    throw Error("Invalid tax recipient or holding threshold");
}
export function validateLaunch(p: LaunchParameters): void {
  validateTax(p.tax);
  const bytes = (s: string) => new TextEncoder().encode(s).length;
  if (
    !bytes(p.name) ||
    bytes(p.name) > 64 ||
    !bytes(p.symbol) ||
    bytes(p.symbol) > 12 ||
    bytes(p.metadataURI) > 256
  )
    throw Error("Invalid launch text length");
  if (
    !isAddress(p.quoteAsset) ||
    !/^0x[0-9a-f]{64}$/i.test(p.salt) ||
    !/^0x[0-9a-f]{64}$/i.test(p.expectedConfig)
  )
    throw Error("Invalid launch address or hash");
  if (p.minTarget <= 0n || p.maxTarget < p.minTarget)
    throw Error("Invalid target bounds");
}
/** Standalone deployer address, not the factory proxy, is the CREATE2 sender. */
export function predictToken(
  deployer: Address,
  initCodeHash: Hex,
  creator: Address,
  salt: Hex,
): Address {
  const effective = keccak256(
    encodeAbiParameters(
      [{ type: "address" }, { type: "bytes32" }],
      [creator, salt],
    ),
  );
  return getCreate2Address({
    from: deployer,
    salt: effective,
    bytecodeHash: initCodeHash,
  });
}
export function buildCreateTransaction(
  p: LaunchParameters,
  creationFee: bigint,
  factory: Address = bscDeployment.factory,
  templateId: bigint = BigInt(bscDeployment.defaultTemplateId),
): UnsignedTransaction {
  validateLaunch(p);
  if(templateId<1n||templateId>255n)throw Error("Invalid template ID");
  if (creationFee < 0n) throw Error("Invalid creation fee");
  return {
    to: factory,
    data: encodeFunctionData({
      abi: factoryAbi,
      functionName: "createTokenWithTemplateV8",
      args: [p, templateId],
    }),
    value: creationFee,
  };
}
export function buildCreateAndBuyTransaction(
  p: LaunchParameters,
  b: DeveloperBuy,
  creationFee: bigint,
  factory: Address = bscDeployment.factory,
  templateId: bigint = BigInt(bscDeployment.defaultTemplateId),
): UnsignedTransaction {
  validateLaunch(p);
  if(templateId<1n||templateId>255n)throw Error("Invalid template ID");
  if (
    creationFee < 0n ||
    b.amount <= 0n ||
    b.minTokens <= 0n ||
    b.deadline <= 0n ||
    b.minQuote < 0n
  )
    throw Error("Invalid first buy");
  if (b.payWithBNB && p.quoteAsset !== zeroAddress && b.minQuote === 0n)
    throw Error("A converted first buy needs a positive minimum quote");
  return {
    to: factory,
    data: encodeFunctionData({
      abi: factoryAbi,
      functionName: "createTokenAndBuyWithTemplateV8",
      args: [p, b, templateId],
    }),
    value:
      creationFee +
      (b.payWithBNB || p.quoteAsset === zeroAddress ? b.amount : 0n),
  };
}
export function buildCurveBuy(
  pool: Address,
  quoteAsset: Address,
  amount: bigint,
  minTokens: bigint,
  deadline: bigint,
  recipient: Address,
): UnsignedTransaction {
  if (amount <= 0n || minTokens <= 0n || deadline <= 0n)
    throw Error("Invalid buy bounds");
  return {
    to: pool,
    data: encodeFunctionData({
      abi: curveAbi,
      functionName: "buy",
      args: [amount, minTokens, deadline, recipient],
    }),
    value: quoteAsset === zeroAddress ? amount : 0n,
  };
}
export function buildCurveSell(
  pool: Address,
  amount: bigint,
  minQuote: bigint,
  deadline: bigint,
  recipient: Address,
): UnsignedTransaction {
  if (amount <= 0n || minQuote <= 0n || deadline <= 0n)
    throw Error("Invalid sell bounds");
  return {
    to: pool,
    data: encodeFunctionData({
      abi: curveAbi,
      functionName: "sell",
      args: [amount, minQuote, deadline, recipient],
    }),
    value: 0n,
  };
}
export function buildBNBBuy(
  router: Address,
  token: Address,
  amount: bigint,
  minQuote: bigint,
  minTokens: bigint,
  deadline: bigint,
  route: SwapRoute,
): UnsignedTransaction {
  if (amount <= 0n || minQuote <= 0n || minTokens <= 0n || deadline <= 0n)
    throw Error("Invalid routed buy bounds");
  return {
    to: router,
    data: encodeFunctionData({
      abi: bnbRouterAbi,
      functionName: "buyWithBNB",
      args: [token, minQuote, minTokens, deadline, route],
    }),
    value: amount,
  };
}
export function buildGraduation(pool: Address): UnsignedTransaction {
  return {
    to: pool,
    data: encodeFunctionData({ abi: curveAbi, functionName: "graduate" }),
    value: 0n,
  };
}
export class PogoClient {
  constructor(
    readonly client: PublicClient,
    readonly factory: Address = bscDeployment.factory,
  ) {}
  async assertChain() {
    if ((await this.client.getChainId()) !== 56)
      throw Error("Expected BNB Chain (56)");
  }
  async launchConfiguration(quoteAsset: Address = zeroAddress, templateId: bigint = BigInt(bscDeployment.defaultTemplateId)) {
    await this.assertChain();
    const [registry, deployment, creationFee, creationPaused, configHash] =
      await Promise.all([
        this.client.readContract({
          address: this.factory,
          abi: factoryAbi,
          functionName: "quoteRegistry",
        }),
        this.client.readContract({
          address: this.factory,
          abi: factoryAbi,
          functionName: "tokenDeploymentConfig",
        }),
        this.client.readContract({
          address: this.factory,
          abi: factoryAbi,
          functionName: "CREATION_FEE",
        }),
        this.client.readContract({
          address: this.factory,
          abi: factoryAbi,
          functionName: "creationPaused",
        }),
        this.client.readContract({
          address: this.factory,
          abi: factoryAbi,
          functionName: "templateConfigHash",
          args: [quoteAsset, templateId],
        }),
      ]);
    const template=await this.client.readContract({address:this.factory,abi:factoryAbi,functionName:"launchTemplates",args:[templateId]});
    if(!template[3])throw Error("Template disabled");
    const [quote, curveVersion] = await Promise.all([
      this.client.readContract({
        address: registry,
        abi: registryAbi,
        functionName: "quoteLaunch",
        args: [quoteAsset],
      }),
      this.client.readContract({
        address: template[0],
        abi: parseAbi(["function CURVE_VERSION() view returns(uint256)"]),
        functionName: "CURVE_VERSION",
      }),
    ]);
    return {
      registry, templateId, vaultDeployer:template[1],
      deployer: deployment[0],
      initCodeHash: deployment[1],
      creationFee,
      creationPaused,
      configHash,
      curveVersion,
      quote,
    };
  }
  async project(token: Address) {
    await this.assertChain();
    const [creator, pool, vault, createdAt] = await this.client.readContract({
      address: this.factory,
      abi: factoryAbi,
      functionName: "projects",
      args: [token],
    });
    if (pool === zeroAddress)
      throw Error("Token is not registered with this factory");
    return { token, creator, pool, vault, createdAt };
  }
  async market(token: Address) {
    const project = await this.project(token),
      address = project.pool;
    const [
      version,
      quoteAsset,
      quoteDecimals,
      virtualQuote,
      target,
      reserveQuote,
      reserveTokens,
      spotPrice,
      progressBps,
      graduated,
      pair,
    ] = await Promise.all([
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "VERSION",
      }),
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "quoteAsset",
      }),
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "quoteDecimals",
      }),
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "virtualQuote",
      }),
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "graduationTarget",
      }),
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "reserveQuote",
      }),
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "reserveTokens",
      }),
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "spotPrice",
      }),
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "progressBps",
      }),
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "graduated",
      }),
      this.client.readContract({
        address,
        abi: curveAbi,
        functionName: "pair",
      }),
    ]);
    return {
      ...project,
      version,
      quoteAsset,
      quoteDecimals,
      virtualQuote,
      target,
      reserveQuote,
      reserveTokens,
      spotPrice,
      progressBps,
      graduated,
      pair,
    };
  }
  quoteBuy(pool: Address, amount: bigint) {
    return this.client.readContract({
      address: pool,
      abi: curveAbi,
      functionName: "quoteBuy",
      args: [amount],
    });
  }
  quoteSell(pool: Address, amount: bigint) {
    return this.client.readContract({
      address: pool,
      abi: curveAbi,
      functionName: "quoteSell",
      args: [amount],
    });
  }
}
