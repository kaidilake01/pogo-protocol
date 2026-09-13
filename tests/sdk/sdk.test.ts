import test from "node:test";
import assert from "node:assert/strict";
import { decodeFunctionData, parseEther, zeroAddress, type Hex } from "viem";
import {
  buildCreateTransaction,
  buildCreateAndBuyTransaction,
  buildCurveBuy,
  buildCurveSell,
  validateTax,
  validateLaunch,
  predictToken,
  candidate,
  initialPriceQuote,
  previewInitialBuy,
  factoryAbi,
  curveAbi,
  type LaunchParameters,
} from "../../sdk/src/index.js";
const creator = "0x1111111111111111111111111111111111111111",
  hash = ("0x" + "ab".repeat(32)) as Hex;
const tax = {
  buyBps: 300,
  sellBps: 300,
  recipientBps: 8000,
  burnBps: 1000,
  holderBps: 500,
  liquidityBps: 500,
  recipient: creator,
  minimumHolding: 0n,
} as const;
const p: LaunchParameters = {
  name: "Test",
  symbol: "TEST",
  metadataURI: "ipfs://test",
  salt: hash,
  quoteAsset: zeroAddress,
  expectedConfig: hash,
  minTarget: parseEther("18"),
  maxTarget: parseEther("18"),
  tax,
};
test("create calldata preserves tax and target bounds and pays only the creation fee", () => {
  const tx = buildCreateTransaction(p, parseEther(".01")),
    decoded = decodeFunctionData({ abi: factoryAbi, data: tx.data });
  assert.equal(tx.value, parseEther(".01"));
  assert.equal(decoded.functionName, "createTokenWithTemplateV8");
  assert.deepEqual(decoded.args?.[0], p);
  assert.equal(decoded.args?.[1],12n);
});
test("tax validation rejects excess total, negative allocations and excessive buy tax", () => {
  assert.throws(() => validateTax({ ...tax, recipientBps: 9000 }));
  assert.throws(() => validateTax({ ...tax, burnBps: -1 }));
  assert.throws(() => validateTax({ ...tax, buyBps: 501 }));
  assert.throws(() => validateTax({ ...tax, recipient: zeroAddress }));
});
test("UTF-8 byte limits and hash lengths match contract limits", () => {
  assert.throws(() => validateLaunch({ ...p, name: "界".repeat(22) }));
  assert.throws(() => validateLaunch({ ...p, salt: "0x00" }));
});
test("native first buy is added to the creation fee, ERC20 first buy is not", () => {
  const b = {
    amount: parseEther(".1"),
    minQuote: 1n,
    minTokens: 1n,
    deadline: 2000000000n,
    payWithBNB: false,
    route: { kind: 0, v2Path: [], v3Path: "0x" as Hex },
  };
  assert.equal(
    buildCreateAndBuyTransaction(p, b, parseEther(".01")).value,
    parseEther(".11"),
  );
  assert.equal(
    buildCreateAndBuyTransaction(
      { ...p, quoteAsset: creator },
      b,
      parseEther(".01"),
    ).value,
    parseEther(".01"),
  );
});
test("converted first buy requires a slippage bound", () => {
  assert.throws(() =>
    buildCreateAndBuyTransaction(
      { ...p, quoteAsset: creator },
      {
        amount: 1n,
        minQuote: 0n,
        minTokens: 1n,
        deadline: 1n,
        payWithBNB: true,
        route: { kind: 2, v2Path: [], v3Path: "0x" },
      },
      1n,
    ),
  );
});
test("curve buy and sell builders encode raw units and native value correctly", () => {
  const tx = buildCurveBuy(
    creator,
    zeroAddress,
    100n,
    1n,
    2000000000n,
    creator,
  );
  assert.equal(tx.value, 100n);
  assert.equal(
    decodeFunctionData({ abi: curveAbi, data: tx.data }).functionName,
    "buy",
  );
  assert.equal(
    buildCurveBuy(creator, creator, 100n, 1n, 2000000000n, creator).value,
    0n,
  );
  assert.equal(
    decodeFunctionData({
      abi: curveAbi,
      data: buildCurveSell(creator, 100n, 1n, 2000000000n, creator).data,
    }).functionName,
    "sell",
  );
});
test("CREATE2 predictions bind the deployer and creator", () => {
  const a = candidate(creator, hash, creator, 42n);
  assert.equal(a.address, predictToken(creator, hash, creator, a.salt));
  assert.notEqual(a.address, predictToken(creator, hash, zeroAddress, a.salt));
});
test("standard initial price and graduation cap match the documented curve", () => {
  const target = parseEther("18"),
    v = (target * 25n + 72n) / 73n;
  assert.equal(initialPriceQuote(target, v, 18, 5), 5739795918n);
  const result = previewInitialBuy(parseEther("100"), target, v, 300, 5);
  assert.equal(result.tokens, parseEther("800000000"));
  assert.equal(result.used + result.refund, parseEther("100"));
  assert.equal(result.used - result.platform - result.tax, target);
});

test("initial-buy default follows the current 6.666 BNB curve", () => {
 const target=parseEther("6.666"), opening=(parseEther("18")*25n+72n)/73n;
 const current=previewInitialBuy(parseEther("8"),target,opening,0);
 assert.deepEqual(current,previewInitialBuy(parseEther("8"),target,opening,0,11));
 assert.equal(current.used-current.platform-current.tax,target);
 assert.equal(current.tokens,557980307873647527569535079n);
});
