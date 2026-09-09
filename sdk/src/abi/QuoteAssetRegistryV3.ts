// Generated from the corresponding Solidity artifact. Do not edit by hand.
export const registryAbi = [
  {
    type: "constructor",
    inputs: [
      {
        name: "owner_",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "CURVE_VERSION",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "STANDARD_TARGET_BNB",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "TARGET_BNB",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "acceptOwnership",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "assetAt",
    inputs: [
      {
        name: "index",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "assetCount",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "assets",
    inputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "feed",
        type: "address",
        internalType: "address",
      },
      {
        name: "feedId",
        type: "bytes4",
        internalType: "bytes4",
      },
      {
        name: "maxAge",
        type: "uint32",
        internalType: "uint32",
      },
      {
        name: "assetDecimals",
        type: "uint8",
        internalType: "uint8",
      },
      {
        name: "feedDecimals",
        type: "uint8",
        internalType: "uint8",
      },
      {
        name: "kind",
        type: "uint8",
        internalType: "uint8",
      },
      {
        name: "enabled",
        type: "bool",
        internalType: "bool",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "configHash",
    inputs: [
      {
        name: "asset",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "",
        type: "bytes32",
        internalType: "bytes32",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "configure",
    inputs: [
      {
        name: "asset",
        type: "address",
        internalType: "address",
      },
      {
        name: "config",
        type: "tuple",
        internalType: "struct QuoteAssetRegistry.Asset",
        components: [
          {
            name: "feed",
            type: "address",
            internalType: "address",
          },
          {
            name: "feedId",
            type: "bytes4",
            internalType: "bytes4",
          },
          {
            name: "maxAge",
            type: "uint32",
            internalType: "uint32",
          },
          {
            name: "assetDecimals",
            type: "uint8",
            internalType: "uint8",
          },
          {
            name: "feedDecimals",
            type: "uint8",
            internalType: "uint8",
          },
          {
            name: "kind",
            type: "uint8",
            internalType: "uint8",
          },
          {
            name: "enabled",
            type: "bool",
            internalType: "bool",
          },
        ],
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "owner",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "pendingOwner",
    inputs: [],
    outputs: [
      {
        name: "",
        type: "address",
        internalType: "address",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "priceUsd",
    inputs: [
      {
        name: "asset",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "price",
        type: "uint256",
        internalType: "uint256",
      },
      {
        name: "updatedAt",
        type: "uint256",
        internalType: "uint256",
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "quoteLaunch",
    inputs: [
      {
        name: "asset",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [
      {
        name: "q",
        type: "tuple",
        internalType: "struct QuoteAssetRegistry.LaunchQuote",
        components: [
          {
            name: "target",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "virtualQuote",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "assetUsd",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "bnbUsd",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "assetUpdatedAt",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "bnbUpdatedAt",
            type: "uint256",
            internalType: "uint256",
          },
          {
            name: "configHash",
            type: "bytes32",
            internalType: "bytes32",
          },
        ],
      },
    ],
    stateMutability: "view",
  },
  {
    type: "function",
    name: "renounceOwnership",
    inputs: [],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "setEnabled",
    inputs: [
      {
        name: "asset",
        type: "address",
        internalType: "address",
      },
      {
        name: "enabled",
        type: "bool",
        internalType: "bool",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "function",
    name: "transferOwnership",
    inputs: [
      {
        name: "newOwner",
        type: "address",
        internalType: "address",
      },
    ],
    outputs: [],
    stateMutability: "nonpayable",
  },
  {
    type: "event",
    name: "AssetConfigured",
    inputs: [
      {
        name: "asset",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "config",
        type: "tuple",
        indexed: false,
        internalType: "struct QuoteAssetRegistry.Asset",
        components: [
          {
            name: "feed",
            type: "address",
            internalType: "address",
          },
          {
            name: "feedId",
            type: "bytes4",
            internalType: "bytes4",
          },
          {
            name: "maxAge",
            type: "uint32",
            internalType: "uint32",
          },
          {
            name: "assetDecimals",
            type: "uint8",
            internalType: "uint8",
          },
          {
            name: "feedDecimals",
            type: "uint8",
            internalType: "uint8",
          },
          {
            name: "kind",
            type: "uint8",
            internalType: "uint8",
          },
          {
            name: "enabled",
            type: "bool",
            internalType: "bool",
          },
        ],
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OwnershipTransferStarted",
    inputs: [
      {
        name: "previousOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "newOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "event",
    name: "OwnershipTransferred",
    inputs: [
      {
        name: "previousOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
      {
        name: "newOwner",
        type: "address",
        indexed: true,
        internalType: "address",
      },
    ],
    anonymous: false,
  },
  {
    type: "error",
    name: "InvalidAsset",
    inputs: [],
  },
  {
    type: "error",
    name: "InvalidPrice",
    inputs: [
      {
        name: "asset",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "OwnableInvalidOwner",
    inputs: [
      {
        name: "owner",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "OwnableUnauthorizedAccount",
    inputs: [
      {
        name: "account",
        type: "address",
        internalType: "address",
      },
    ],
  },
  {
    type: "error",
    name: "StalePrice",
    inputs: [
      {
        name: "asset",
        type: "address",
        internalType: "address",
      },
    ],
  },
] as const;
