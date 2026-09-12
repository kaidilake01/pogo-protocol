export const factoryAbi = [
  {
    "type": "receive",
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "CREATION_FEE",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "FREE_CREATION_VERSION",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "LAUNCH_TEMPLATES_VERSION",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MINING_LAUNCH_VERSION",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "MULTI_ASSET_VERSION",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "PROTOCOL_VERSION",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "STANDALONE_VERSION",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "UPGRADE_INTERFACE_VERSION",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "string",
        "internalType": "string"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "acceptOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "allowedRewardAssets",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "bnbAdapter",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract BNBQuoteAdapter"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "claimCreationFees",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "configureLaunchTemplates",
    "inputs": [
      {
        "name": "fair_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "mining_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "vault_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "configureMiningLaunches",
    "inputs": [
      {
        "name": "registry_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "curve_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "vault_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "configureStandardLaunches",
    "inputs": [
      {
        "name": "registry_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "token_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "curve_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "createToken",
    "inputs": [
      {
        "name": "",
        "type": "tuple",
        "internalType": "struct LaunchFactory.CreateParams",
        "components": [
          {
            "name": "name",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "symbol",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "metadataURI",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "salt",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "expectedImplementation",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "revenueBps",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "burnBps",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "holderShareBps",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "buybackShareBps",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "rewardMode",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "burnMode",
            "type": "uint8",
            "internalType": "uint8"
          },
          {
            "name": "extraRewardAsset",
            "type": "address",
            "internalType": "address"
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createTokenAndBuyV3",
    "inputs": [
      {
        "name": "p",
        "type": "tuple",
        "internalType": "struct LaunchFactoryV3.CreateParamsV3",
        "components": [
          {
            "name": "name",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "symbol",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "metadataURI",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "salt",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "quoteAsset",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "expectedConfig",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "minTarget",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxTarget",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "tax",
            "type": "tuple",
            "internalType": "struct LaunchTypes.Tax",
            "components": [
              {
                "name": "buyBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "sellBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "recipientBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "burnBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "holderBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "liquidityBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "recipient",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "minimumHolding",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          }
        ]
      },
      {
        "name": "b",
        "type": "tuple",
        "internalType": "struct LaunchFactoryV3.DeveloperBuy",
        "components": [
          {
            "name": "amount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minQuote",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minTokens",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "deadline",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "payWithBNB",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "route",
            "type": "tuple",
            "internalType": "struct BNBQuoteAdapter.Route",
            "components": [
              {
                "name": "kind",
                "type": "uint8",
                "internalType": "uint8"
              },
              {
                "name": "v2Path",
                "type": "address[]",
                "internalType": "address[]"
              },
              {
                "name": "v3Path",
                "type": "bytes",
                "internalType": "bytes"
              }
            ]
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createTokenAndBuyWithTemplateV8",
    "inputs": [
      {
        "name": "p",
        "type": "tuple",
        "internalType": "struct LaunchFactoryV3.CreateParamsV3",
        "components": [
          {
            "name": "name",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "symbol",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "metadataURI",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "salt",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "quoteAsset",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "expectedConfig",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "minTarget",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxTarget",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "tax",
            "type": "tuple",
            "internalType": "struct LaunchTypes.Tax",
            "components": [
              {
                "name": "buyBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "sellBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "recipientBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "burnBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "holderBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "liquidityBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "recipient",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "minimumHolding",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          }
        ]
      },
      {
        "name": "b",
        "type": "tuple",
        "internalType": "struct LaunchFactoryV3.DeveloperBuy",
        "components": [
          {
            "name": "amount",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minQuote",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "minTokens",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "deadline",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "payWithBNB",
            "type": "bool",
            "internalType": "bool"
          },
          {
            "name": "route",
            "type": "tuple",
            "internalType": "struct BNBQuoteAdapter.Route",
            "components": [
              {
                "name": "kind",
                "type": "uint8",
                "internalType": "uint8"
              },
              {
                "name": "v2Path",
                "type": "address[]",
                "internalType": "address[]"
              },
              {
                "name": "v3Path",
                "type": "bytes",
                "internalType": "bytes"
              }
            ]
          }
        ]
      },
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createTokenV3",
    "inputs": [
      {
        "name": "p",
        "type": "tuple",
        "internalType": "struct LaunchFactoryV3.CreateParamsV3",
        "components": [
          {
            "name": "name",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "symbol",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "metadataURI",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "salt",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "quoteAsset",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "expectedConfig",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "minTarget",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxTarget",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "tax",
            "type": "tuple",
            "internalType": "struct LaunchTypes.Tax",
            "components": [
              {
                "name": "buyBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "sellBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "recipientBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "burnBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "holderBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "liquidityBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "recipient",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "minimumHolding",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          }
        ]
      }
    ],
    "outputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "createTokenWithTemplateV8",
    "inputs": [
      {
        "name": "p",
        "type": "tuple",
        "internalType": "struct LaunchFactoryV3.CreateParamsV3",
        "components": [
          {
            "name": "name",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "symbol",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "metadataURI",
            "type": "string",
            "internalType": "string"
          },
          {
            "name": "salt",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "quoteAsset",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "expectedConfig",
            "type": "bytes32",
            "internalType": "bytes32"
          },
          {
            "name": "minTarget",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "maxTarget",
            "type": "uint256",
            "internalType": "uint256"
          },
          {
            "name": "tax",
            "type": "tuple",
            "internalType": "struct LaunchTypes.Tax",
            "components": [
              {
                "name": "buyBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "sellBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "recipientBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "burnBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "holderBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "liquidityBps",
                "type": "uint16",
                "internalType": "uint16"
              },
              {
                "name": "recipient",
                "type": "address",
                "internalType": "address"
              },
              {
                "name": "minimumHolding",
                "type": "uint256",
                "internalType": "uint256"
              }
            ]
          }
        ]
      },
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "creationCredits",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "creationPaused",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "effectiveSalt",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "salt",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "pure"
  },
  {
    "type": "function",
    "name": "initialize",
    "inputs": [
      {
        "name": "owner_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "treasury_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "router_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "token_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "vault_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "pool_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "launchConfigHash",
    "inputs": [
      {
        "name": "quote",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "launchTemplateCount",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "launchTemplateIds",
    "inputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "launchTemplates",
    "inputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "curveDeployer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "vaultDeployer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "kind",
        "type": "uint8",
        "internalType": "uint8"
      },
      {
        "name": "enabled",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "owner",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "pendingOwner",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "poolImplementation",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "poolImplementationV3",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "predictToken",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "salt",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "predictTokenV3",
    "inputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "salt",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "projectTemplate",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "projectVersion",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "projects",
    "inputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [
      {
        "name": "creator",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "pool",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "vault",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "createdAt",
        "type": "uint64",
        "internalType": "uint64"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "proxiableUUID",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "quoteRegistry",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract QuoteAssetRegistry"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "registerLaunchTemplate",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "curve_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "vault_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "kind_",
        "type": "uint8",
        "internalType": "uint8"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "renounceOwnership",
    "inputs": [],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "router",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "setBNBAdapter",
    "inputs": [
      {
        "name": "adapter",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setCreationPaused",
    "inputs": [
      {
        "name": "paused",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setLaunchTemplateEnabled",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      },
      {
        "name": "enabled",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setRewardAsset",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "allowed",
        "type": "bool",
        "internalType": "bool"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setStandaloneDeployers",
    "inputs": [
      {
        "name": "token_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "curve_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "vault_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTemplates",
    "inputs": [
      {
        "name": "token_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "vault_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "pool_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTemplatesV3",
    "inputs": [
      {
        "name": "registry_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "token_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "vault_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "pool_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTradeRouterV3",
    "inputs": [
      {
        "name": "router_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "setTradingTemplate",
    "inputs": [
      {
        "name": "pool_",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "router_",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "standaloneCurveDeployer",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract StandaloneCurveDeployer"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "standaloneTokenDeployer",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract StandaloneTokenDeployer"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "standaloneVaultDeployer",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "contract StandaloneVaultDeployer"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "templateConfigHash",
    "inputs": [
      {
        "name": "quote",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "id",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "templateVersion",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "templateVersionV3",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint32",
        "internalType": "uint32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tokenCount",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tokenDeploymentConfig",
    "inputs": [],
    "outputs": [
      {
        "name": "deployer",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "initCodeHash",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tokenImplementation",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tokenImplementationV3",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tokens",
    "inputs": [
      {
        "name": "",
        "type": "uint256",
        "internalType": "uint256"
      }
    ],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "tradeRouterV3",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "transferOwnership",
    "inputs": [
      {
        "name": "newOwner",
        "type": "address",
        "internalType": "address"
      }
    ],
    "outputs": [],
    "stateMutability": "nonpayable"
  },
  {
    "type": "function",
    "name": "treasury",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "upgradeToAndCall",
    "inputs": [
      {
        "name": "newImplementation",
        "type": "address",
        "internalType": "address"
      },
      {
        "name": "data",
        "type": "bytes",
        "internalType": "bytes"
      }
    ],
    "outputs": [],
    "stateMutability": "payable"
  },
  {
    "type": "function",
    "name": "vaultImplementation",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "function",
    "name": "vaultImplementationV3",
    "inputs": [],
    "outputs": [
      {
        "name": "",
        "type": "address",
        "internalType": "address"
      }
    ],
    "stateMutability": "view"
  },
  {
    "type": "event",
    "name": "BNBAdapterUpdated",
    "inputs": [
      {
        "name": "adapter",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "CreationPauseChanged",
    "inputs": [
      {
        "name": "paused",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "DeveloperBought",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "developer",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "inputAmount",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "paidBNB",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      },
      {
        "name": "tokens",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Initialized",
    "inputs": [
      {
        "name": "version",
        "type": "uint64",
        "indexed": false,
        "internalType": "uint64"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "LaunchTemplateEnabled",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "enabled",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "LaunchTemplateRegistered",
    "inputs": [
      {
        "name": "id",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      },
      {
        "name": "curveDeployer",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "vaultDeployer",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "kind",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OwnershipTransferStarted",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "OwnershipTransferred",
    "inputs": [
      {
        "name": "previousOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "newOwner",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "ProjectTemplateSelected",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "templateId",
        "type": "uint256",
        "indexed": true,
        "internalType": "uint256"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "RewardAssetAllowed",
    "inputs": [
      {
        "name": "asset",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "allowed",
        "type": "bool",
        "indexed": false,
        "internalType": "bool"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "StandaloneDeployersConfigured",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "curve",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "vault",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TemplatesUpdated",
    "inputs": [
      {
        "name": "version",
        "type": "uint32",
        "indexed": false,
        "internalType": "uint32"
      },
      {
        "name": "tokenImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "vaultImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "poolImplementation",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TemplatesV3Updated",
    "inputs": [
      {
        "name": "version",
        "type": "uint32",
        "indexed": false,
        "internalType": "uint32"
      },
      {
        "name": "registry",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "token",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "vault",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "pool",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TokenCreated",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "creator",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "pool",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "vault",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "name",
        "type": "string",
        "indexed": false,
        "internalType": "string"
      },
      {
        "name": "symbol",
        "type": "string",
        "indexed": false,
        "internalType": "string"
      },
      {
        "name": "metadataURI",
        "type": "string",
        "indexed": false,
        "internalType": "string"
      },
      {
        "name": "revenueBps",
        "type": "uint16",
        "indexed": false,
        "internalType": "uint16"
      },
      {
        "name": "burnBps",
        "type": "uint16",
        "indexed": false,
        "internalType": "uint16"
      },
      {
        "name": "holderShareBps",
        "type": "uint16",
        "indexed": false,
        "internalType": "uint16"
      },
      {
        "name": "buybackShareBps",
        "type": "uint16",
        "indexed": false,
        "internalType": "uint16"
      },
      {
        "name": "rewardMode",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      },
      {
        "name": "burnMode",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      },
      {
        "name": "extraRewardAsset",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TokenCreatedV3",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "creator",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "quoteAsset",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      },
      {
        "name": "pool",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "vault",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      },
      {
        "name": "name",
        "type": "string",
        "indexed": false,
        "internalType": "string"
      },
      {
        "name": "symbol",
        "type": "string",
        "indexed": false,
        "internalType": "string"
      },
      {
        "name": "metadataURI",
        "type": "string",
        "indexed": false,
        "internalType": "string"
      },
      {
        "name": "tax",
        "type": "tuple",
        "indexed": false,
        "internalType": "struct LaunchTypes.Tax",
        "components": [
          {
            "name": "buyBps",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "sellBps",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "recipientBps",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "burnBps",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "holderBps",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "liquidityBps",
            "type": "uint16",
            "internalType": "uint16"
          },
          {
            "name": "recipient",
            "type": "address",
            "internalType": "address"
          },
          {
            "name": "minimumHolding",
            "type": "uint256",
            "internalType": "uint256"
          }
        ]
      },
      {
        "name": "target",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "virtualQuote",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "assetUsd",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "bnbUsd",
        "type": "uint256",
        "indexed": false,
        "internalType": "uint256"
      },
      {
        "name": "quoteDecimals",
        "type": "uint8",
        "indexed": false,
        "internalType": "uint8"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "TradeRouterUpdated",
    "inputs": [
      {
        "name": "router",
        "type": "address",
        "indexed": false,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "event",
    "name": "Upgraded",
    "inputs": [
      {
        "name": "implementation",
        "type": "address",
        "indexed": true,
        "internalType": "address"
      }
    ],
    "anonymous": false
  },
  {
    "type": "error",
    "name": "AddressEmptyCode",
    "inputs": [
      {
        "name": "target",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "CreationPaused",
    "inputs": []
  },
  {
    "type": "error",
    "name": "ERC1967InvalidImplementation",
    "inputs": [
      {
        "name": "implementation",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "ERC1967NonPayable",
    "inputs": []
  },
  {
    "type": "error",
    "name": "FailedCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidConfig",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidInitialization",
    "inputs": []
  },
  {
    "type": "error",
    "name": "InvalidSuffix",
    "inputs": []
  },
  {
    "type": "error",
    "name": "LegacyCreationDisabled",
    "inputs": []
  },
  {
    "type": "error",
    "name": "NotInitializing",
    "inputs": []
  },
  {
    "type": "error",
    "name": "OwnableInvalidOwner",
    "inputs": [
      {
        "name": "owner",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "OwnableUnauthorizedAccount",
    "inputs": [
      {
        "name": "account",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "ReentrancyGuardReentrantCall",
    "inputs": []
  },
  {
    "type": "error",
    "name": "SafeERC20FailedOperation",
    "inputs": [
      {
        "name": "token",
        "type": "address",
        "internalType": "address"
      }
    ]
  },
  {
    "type": "error",
    "name": "TransferFailed",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UUPSUnauthorizedCallContext",
    "inputs": []
  },
  {
    "type": "error",
    "name": "UUPSUnsupportedProxiableUUID",
    "inputs": [
      {
        "name": "slot",
        "type": "bytes32",
        "internalType": "bytes32"
      }
    ]
  }
] as const;
