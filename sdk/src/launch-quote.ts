import { initialVirtualTokens, SALE_SUPPLY } from "./curve-economics.js";
/** Integer arithmetic shared with the immutable curve selected by the launch quote. */
export function previewInitialBuy(
  amount: bigint,
  target: bigint,
  virtualQuote: bigint,
  taxBps: number,
  version = 3,
) {
  const denominator = 10000n - 100n - BigInt(taxBps);
  const max = (target * 10000n + denominator - 1n) / denominator;
  let used = amount < max ? amount : max;
  const platform = used / 100n,
    tax = (used * BigInt(taxBps)) / 10000n;
  let net = used - platform - tax;
  if (net > target) {
    used -= net - target;
    net = target;
  }
  const calculated =
    virtualQuote + net > 0n
      ? (initialVirtualTokens(target, virtualQuote, version) * net) /
        (virtualQuote + net)
      : 0n;
  const tokens =
    version >= 5
      ? net === target
        ? SALE_SUPPLY
        : calculated > SALE_SUPPLY
          ? SALE_SUPPLY
          : calculated
      : calculated;
  return { tokens, used, refund: amount - used, platform, tax };
}
