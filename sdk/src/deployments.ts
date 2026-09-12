/** Public snapshot; refresh configuration on chain before signing. */
export const bscDeployment = {
  "factory": "0x0abc6174ee9f9600243D14F83E215993b8BbABEb",
  "registry": "0x65b2dfae97e405a6435922d7c0d5431807bcd2bb",
  "implementation": "0xc8C820a3DEc5666E9a4B02275E293a6f15f4b813",
  "vaultDeployer": "0xD8FeFE95d325c918a4c7E2754967567E41922cc3",
  "miningDeployer": "0x97cA4D7458165567e6865942B7e33C78EC1524b8",
  "miningCurveDeployer": "0xd6253A2a4475Ca5Be9c025FbCd7932485Ca317cA",
  "fairCurveDeployer": "0x5D7B1415888d64b5023Fa0ad16C7016aC98a39A5",
  "enabledTemplateIds": [
    11,
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
  "curveDeployer": "0xd6253A2a4475Ca5Be9c025FbCd7932485Ca317cA",
  "curveVersion": 11,
  "defaultTemplateId": 11,
  "rewardSplitBps": [
    625,
    3125,
    6250
  ],
  "miningVersion": 13
} as const;
