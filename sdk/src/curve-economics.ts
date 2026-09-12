export const TOKEN_SUPPLY=1_000_000_000n*10n**18n;
export const SALE_SUPPLY=800_000_000n*10n**18n;
export const ORIGINAL_VIRTUAL_TOKENS=(SALE_SUPPLY*98n+72n)/73n;
export function initialVirtualTokens(target:bigint,virtualQuote:bigint,version=3){
  return version>=6?ORIGINAL_VIRTUAL_TOKENS:version>=5?(SALE_SUPPLY*(target+virtualQuote)+target-1n)/target:TOKEN_SUPPLY;
}
export function inferCurveVersion(target:bigint,virtualQuote:bigint){
  const v5=virtualQuote*73n-target*25n;
  if(v5>=0n&&v5<73n)return 5;
  // Temporary 0.1 BNB mining target keeps the original 18 BNB opening reserves.
  // Both quote conversions round upward; permit only the resulting integer dust.
  const testMining=virtualQuote*73n-target*4500n;
  if(testMining>-4500n&&testMining<73n)return 6;
  const smallTest=virtualQuote*73n-target*45000n;
  if(smallTest>-45000n&&smallTest<73n)return 6;
  const v6=virtualQuote*81103n-target*75000n;
  return v6>-75000n&&v6<81103n?6:3;
}
export function curveAllocation(target:bigint,virtualQuote:bigint,version=3){
  const virtualTokens=initialVirtualTokens(target,virtualQuote,version);
  const sold=version>=6?virtualTokens*target/(target+virtualQuote):version>=5?SALE_SUPPLY:virtualTokens*target/(target+virtualQuote);
  const quote=target-target*200n/10000n;
  const liquidity=version>=6?quote*(virtualTokens-sold)/(virtualQuote+target):TOKEN_SUPPLY-sold;
  const surplus=version>=6?TOKEN_SUPPLY-sold-liquidity:0n;
  return {sold,liquidity,surplus,mining:[7,8,9].includes(version)?0n:surplus,burned:version===7?surplus:0n,locked:version===8?surplus:0n,transferred:version===9?surplus:0n};
}
export function initialPriceQuote(target:bigint,virtualQuote:bigint,decimals:number,version=3){
  return virtualQuote*10n**36n/initialVirtualTokens(target,virtualQuote,version)/10n**BigInt(decimals);
}
