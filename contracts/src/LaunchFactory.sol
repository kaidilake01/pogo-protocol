// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";
import {
    Ownable2StepUpgradeable
} from "@openzeppelin/contracts-upgradeable/access/Ownable2StepUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts/proxy/utils/UUPSUpgradeable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LaunchToken} from "./LaunchToken.sol";
import {DividendVault} from "./DividendVault.sol";
import {BondingCurve} from "./BondingCurve.sol";
import {IV2Router} from "./Interfaces.sol";

contract LaunchFactory is Ownable2StepUpgradeable, UUPSUpgradeable, ReentrancyGuard {
    uint256 public constant CREATION_FEE = 0.01 ether;
    uint256 public constant PROTOCOL_VERSION = 2;
    address public tokenImplementation;
    address public vaultImplementation;
    address public poolImplementation;
    address public treasury;
    address public router;
    uint32 public templateVersion;
    bool public creationPaused;
    uint256 public creationCredits;
    mapping(address => bool) public allowedRewardAssets;
    address[] public tokens;

    struct Project {
        address creator;
        address pool;
        address vault;
        uint64 createdAt;
    }

    struct CreateParams {
        string name;
        string symbol;
        string metadataURI;
        bytes32 salt;
        address expectedImplementation;
        uint16 revenueBps;
        uint16 burnBps;
        uint16 holderShareBps;
        uint16 buybackShareBps;
        uint8 rewardMode;
        uint8 burnMode;
        address extraRewardAsset;
    }
    mapping(address => Project) public projects;
    error InvalidConfig();
    error InvalidSuffix();
    error CreationPaused();
    error TransferFailed();
    event TokenCreated(
        address indexed token,
        address indexed creator,
        address pool,
        address vault,
        string name,
        string symbol,
        string metadataURI,
        uint16 revenueBps,
        uint16 burnBps,
        uint16 holderShareBps,
        uint16 buybackShareBps,
        uint8 rewardMode,
        uint8 burnMode,
        address extraRewardAsset
    );
    event RewardAssetAllowed(address indexed asset, bool allowed);
    event CreationPauseChanged(bool paused);
    event TemplatesUpdated(
        uint32 version, address tokenImplementation, address vaultImplementation, address poolImplementation
    );

    constructor() {
        _disableInitializers();
    }

    function initialize(
        address owner_,
        address treasury_,
        address router_,
        address token_,
        address vault_,
        address pool_
    ) external initializer {
        if (owner_ == address(0)) revert InvalidConfig();
        __Ownable_init(owner_);
        __Ownable2Step_init();
        if (treasury_ == address(0) || router_.code.length == 0) revert InvalidConfig();
        if (IV2Router(router_).WETH().code.length == 0 || IV2Router(router_).factory().code.length == 0) {
            revert InvalidConfig();
        }
        treasury = treasury_;
        router = router_;
        if (token_.code.length == 0 || vault_.code.length == 0 || pool_.code.length == 0) {
            revert InvalidConfig();
        }
        tokenImplementation = token_;
        vaultImplementation = vault_;
        poolImplementation = pool_;
        templateVersion = 1;
        emit TemplatesUpdated(1, tokenImplementation, vaultImplementation, poolImplementation);
    }
    function _authorizeUpgrade(address) internal override onlyOwner {}

    /// @notice Existing EIP-1167 clones keep their implementation forever. Only future launches change.
    function setTemplates(address token_, address vault_, address pool_) external onlyOwner {
        if (token_.code.length == 0 || vault_.code.length == 0 || pool_.code.length == 0) {
            revert InvalidConfig();
        }
        tokenImplementation = token_;
        vaultImplementation = vault_;
        poolImplementation = pool_;
        templateVersion++;
        emit TemplatesUpdated(templateVersion, token_, vault_, pool_);
    }

    function tokenCount() external view returns (uint256) {
        return tokens.length;
    }

    function effectiveSalt(address creator, bytes32 salt) public pure returns (bytes32) {
        return keccak256(abi.encode(creator, salt));
    }

    function predictToken(address creator, bytes32 salt) public view returns (address) {
        return
            Clones.predictDeterministicAddress(
                tokenImplementation, effectiveSalt(creator, salt), address(this)
            );
    }

    function createToken(CreateParams calldata p) external payable virtual nonReentrant returns (address token) {
        if (creationPaused) revert CreationPaused();
        if (
            p.expectedImplementation != tokenImplementation || msg.value != CREATION_FEE
                || bytes(p.name).length == 0 || bytes(p.name).length > 64 || bytes(p.symbol).length == 0
                || bytes(p.symbol).length > 12 || bytes(p.metadataURI).length > 256 || p.revenueBps > 500
                || p.burnBps > 200 || uint256(p.holderShareBps) + p.buybackShareBps > 10_000
                || p.rewardMode > 1 || p.burnMode > 3
                || (p.rewardMode == 0 && (p.holderShareBps != 0 || p.extraRewardAsset != address(0)))
                || (p.rewardMode == 1 && p.holderShareBps == 0)
                || ((p.burnMode == 0 || p.burnMode == 2) && p.burnBps != 0)
                || ((p.burnMode == 1 || p.burnMode == 3) && p.burnBps == 0)
                || (p.burnMode < 2 && p.buybackShareBps != 0)
                || (p.burnMode >= 2 && (p.buybackShareBps == 0 || p.revenueBps == 0))
                || (p.extraRewardAsset != address(0) && !allowedRewardAssets[p.extraRewardAsset])
        ) revert InvalidConfig();
        if (uint160(predictToken(msg.sender, p.salt)) & 0xffff != 0x6666) revert InvalidSuffix();
        token = Clones.cloneDeterministic(tokenImplementation, effectiveSalt(msg.sender, p.salt));
        address pool = Clones.clone(poolImplementation);
        address vault = Clones.clone(vaultImplementation);
        DividendVault(payable(vault))
            .initialize(
                token, msg.sender, pool, router, p.extraRewardAsset, p.holderShareBps, p.buybackShareBps
            );
        LaunchToken(token)
            .initialize(
                LaunchToken.Init(
                    p.name,
                    p.symbol,
                    p.metadataURI,
                    pool,
                    vault,
                    p.revenueBps,
                    p.burnBps,
                    p.rewardMode,
                    p.burnMode
                )
            );
        BondingCurve(pool).initialize(token, vault, treasury, router);
        projects[token] = Project(msg.sender, pool, vault, uint64(block.timestamp));
        tokens.push(token);
        creationCredits += msg.value;
        emit TokenCreated(
            token,
            msg.sender,
            pool,
            vault,
            p.name,
            p.symbol,
            p.metadataURI,
            p.revenueBps,
            p.burnBps,
            p.holderShareBps,
            p.buybackShareBps,
            p.rewardMode,
            p.burnMode,
            p.extraRewardAsset
        );
    }

    function setCreationPaused(bool paused) external onlyOwner {
        creationPaused = paused;
        emit CreationPauseChanged(paused);
    }

    function setRewardAsset(address asset, bool allowed) external onlyOwner {
        if (asset == address(0) || (allowed && asset.code.length == 0)) revert InvalidConfig();
        allowedRewardAssets[asset] = allowed;
        emit RewardAssetAllowed(asset, allowed);
    }

    function claimCreationFees() external nonReentrant {
        uint256 amount = creationCredits;
        creationCredits = 0;
        (bool ok,) = treasury.call{value: amount}("");
        if (!ok) revert TransferFailed();
    }
}
