/** Public snapshot; refresh configuration on chain before signing. */
export const bscDeployment = {
  "factory": "0x0abc6174ee9f9600243D14F83E215993b8BbABEb",
  "registry": "0x65b2dfae97e405a6435922d7c0d5431807bcd2bb",
  "implementation": "0xc8C820a3DEc5666E9a4B02275E293a6f15f4b813",
  "vaultDeployer": "0xD8FeFE95d325c918a4c7E2754967567E41922cc3",
  "miningDeployer": "0x48E0566260EBC80430dF2E2192A2e7F9a5b6dFc1",
  "miningCurveDeployer": "0x1A593de3C1EF91c7474a0D1b20b98eE1FEaDE572",
  "fairCurveDeployer": "0x5D7B1415888d64b5023Fa0ad16C7016aC98a39A5",
  "enabledTemplateIds": [
    9,
    10
  ],
  "dividendAssetVersion": 1,
  "targetBNB": "0.01",
  "creationFeeWei": "0",
  "tokenDeployer": "0x3e94eE9FFB68Ea159C1DFb2B673C10ce144396Dd",
  "bnbAdapter": "0x8218Bb0A3b3E14600FAAfaEbcb55B5B89BD561bB",
  "bnbTradeRouter": "0xAf351493CdA7D60558289d28C3D722331F1c029B",
  "pancakeV2Router": "0x10ED43C718714eb63d5aA57B78B54704E256024E",
  "wrappedBNB": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
  "chainId": 56,
  "asOf": "2026-09-12",
  "curveDeployer": "0x1A593de3C1EF91c7474a0D1b20b98eE1FEaDE572",
  "curveVersion": 11,
  "defaultTemplateId": 9
} as const;
