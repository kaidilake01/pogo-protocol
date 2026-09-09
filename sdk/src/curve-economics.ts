export const TOKEN_SUPPLY = 1_000_000_000n * 10n ** 18n;
export const SALE_SUPPLY = 800_000_000n * 10n ** 18n;
export function initialVirtualTokens(
  target: bigint,
  virtualQuote: bigint,
  version = 3,
) {
  return version >= 5
    ? (SALE_SUPPLY * (target + virtualQuote) + target - 1n) / target
    : TOKEN_SUPPLY;
}
export function initialPriceQuote(
  target: bigint,
  virtualQuote: bigint,
  decimals: number,
  version = 3,
) {
  return (
    (virtualQuote * 10n ** 36n) /
    initialVirtualTokens(target, virtualQuote, version) /
    10n ** BigInt(decimals)
  );
}
