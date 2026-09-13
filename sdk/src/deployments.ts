/** Public snapshot; refresh configuration on chain before signing. */
export const bscDeployment = {
  "factory": "0x0abc6174ee9f9600243D14F83E215993b8BbABEb",
  "registry": "0xe15f2884D6C36Bee3aafc38859F1F2f54046A730",
  "implementation": "0xc8C820a3DEc5666E9a4B02275E293a6f15f4b813",
  "vaultDeployer": "0xD8FeFE95d325c918a4c7E2754967567E41922cc3",
  "miningDeployer": "0x066997F23fc2ba8006D340c75925582B7f253e62",
  "miningCurveDeployer": "0x17160724C60bA4eA8d0C18690bd73d9c844eD388",
  "fairCurveDeployer": "0x5D7B1415888d64b5023Fa0ad16C7016aC98a39A5",
  "enabledTemplateIds": [
    12,
    10
  ],
  "dividendAssetVersion": 1,
  "targetBNB": "6.666",
  "creationFeeWei": "0",
  "tokenDeployer": "0x3e94eE9FFB68Ea159C1DFb2B673C10ce144396Dd",
  "bnbAdapter": "0x8218Bb0A3b3E14600FAAfaEbcb55B5B89BD561bB",
  "bnbTradeRouter": "0xAf351493CdA7D60558289d28C3D722331F1c029B",
  "pancakeV2Router": "0x10ED43C718714eb63d5aA57B78B54704E256024E",
  "wrappedBNB": "0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c",
  "chainId": 56,
  "asOf": "2026-09-13",
  "curveDeployer": "0x17160724C60bA4eA8d0C18690bd73d9c844eD388",
  "curveVersion": 11,
  "defaultTemplateId": 12,
  "rewardSplitBps": [
    400,
    1600,
    8000
  ],
  "miningVersion": 14,
  "pepeFeed": "0xf2896b87a53A244207092E6d51eA2b00131e6218"
} as const;
