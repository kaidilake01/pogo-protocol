// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LaunchToken} from "./LaunchToken.sol";
import {IRewardVault, IV2Factory, IV2Router, IV2Pair, IWBNB} from "./Interfaces.sol";

contract BondingCurve is ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 public constant VIRTUAL_BNB = 10 ether;
    // At 20 BNB: 266.666m virtual tokens and 466.666m real tokens remain.
    // Seed 200m at the final curve price, burn the surplus. No price discontinuity from allocation.
    uint256 public constant VIRTUAL_TOKENS = 800_000_000 ether;
    uint256 public constant TARGET = 20 ether;
    uint256 public constant PLATFORM_BPS = 100;
    uint256 public reserveBNB;
    uint256 public reserveTokens;
    uint256 public platformCredit;
    uint256 public volumeBNB;
    uint256 public tradeCount;
    address public token;
    address public vault;
    address public treasury;
    address public router;
    address public pair;
    bool public graduated;
    bool private initialized;

    error InvalidConfig();
    error InvalidAmount();
    error Slippage();
    error Deadline();
    error Graduated();
    error NotReady();
    error TransferFailed();
    event Trade(
        address indexed trader,
        bool indexed isBuy,
        uint256 bnbAmount,
        uint256 tokenAmount,
        uint256 price,
        uint256 reserveBNB,
        uint256 burned
    );
    event Graduation(address indexed token, address indexed pair, uint256 bnb, uint256 tokens, uint256 lp);
    event PlatformClaimed(uint256 amount);

    constructor() {
        initialized = true;
    }

    function initialize(address token_, address vault_, address treasury_, address router_) external {
        if (
            initialized || token_ == address(0) || vault_ == address(0) || treasury_ == address(0)
                || router_ == address(0)
        ) revert InvalidConfig();
        initialized = true;
        token = token_;
        vault = vault_;
        treasury = treasury_;
        router = router_;
        reserveTokens = VIRTUAL_TOKENS;
        address wrapped = IV2Router(router_).WETH();
        address dexFactory = IV2Router(router_).factory();
        address futurePair = IV2Factory(dexFactory).getPair(token_, wrapped);
        if (futurePair == address(0)) futurePair = IV2Factory(dexFactory).createPair(token_, wrapped);
        LaunchToken(token_).reservePair(futurePair);
    }

    function spotPrice() public view returns (uint256) {
        return (VIRTUAL_BNB + reserveBNB) * 1e18 / reserveTokens;
    }

    function progressBps() external view returns (uint256) {
        return reserveBNB * 10_000 / TARGET;
    }

    function quoteBuy(uint256 bnbIn)
        public
        view
        returns (
            uint256 tokensOut,
            uint256 usedBNB,
            uint256 refund,
            uint256 platformFee,
            uint256 revenue,
            uint256 burned
        )
    {
        if (graduated || reserveBNB >= TARGET || bnbIn == 0) {
            return (0, 0, bnbIn, 0, 0, 0);
        }
        uint256 tax = LaunchToken(token).revenueBps();
        uint256 maxGross =
            Math.mulDiv(TARGET - reserveBNB, 10_000, 10_000 - PLATFORM_BPS - tax, Math.Rounding.Ceil);
        usedBNB = bnbIn < maxGross ? bnbIn : maxGross;
        platformFee = usedBNB * PLATFORM_BPS / 10_000;
        revenue = usedBNB * tax / 10_000;
        uint256 net = usedBNB - platformFee - revenue;
        if (net > TARGET - reserveBNB) {
            revenue += net - (TARGET - reserveBNB);
            net = TARGET - reserveBNB;
        }
        uint256 grossTokens = reserveTokens * net / (VIRTUAL_BNB + reserveBNB + net);
        burned = grossTokens * LaunchToken(token).burnBps() / 10_000;
        tokensOut = grossTokens - burned;
        refund = bnbIn - usedBNB;
    }

    function buy(uint256 minTokens, uint256 deadline, address recipient) external payable nonReentrant {
        if (block.timestamp > deadline) revert Deadline();
        if (graduated || reserveBNB >= TARGET) revert Graduated();
        if (recipient == address(0) || recipient == address(this)) revert InvalidConfig();
        (uint256 out, uint256 used, uint256 refund, uint256 fee, uint256 revenue, uint256 burned) =
            quoteBuy(msg.value);
        if (out == 0) revert InvalidAmount();
        if (out < minTokens) revert Slippage();
        reserveTokens -= out + burned;
        reserveBNB += used - fee - revenue;
        platformCredit += fee;
        volumeBNB += used;
        tradeCount++;
        if (burned != 0) LaunchToken(token).burn(burned);
        IERC20(token).safeTransfer(recipient, out);
        if (revenue != 0) IRewardVault(vault).notifyBNB{value: revenue}();
        if (refund != 0) _send(msg.sender, refund);
        emit Trade(
            recipient, true, used, out, (used - fee - revenue) * 1e18 / (out + burned), reserveBNB, burned
        );
    }

    function quoteSell(uint256 tokenIn)
        public
        view
        returns (uint256 bnbOut, uint256 platformFee, uint256 revenue, uint256 burned)
    {
        if (graduated || tokenIn == 0) return (0, 0, 0, 0);
        burned = tokenIn * LaunchToken(token).burnBps() / 10_000;
        uint256 net = tokenIn - burned;
        uint256 gross = (VIRTUAL_BNB + reserveBNB) * net / (reserveTokens + net);
        if (gross > reserveBNB) return (0, 0, 0, burned);
        platformFee = gross * PLATFORM_BPS / 10_000;
        revenue = gross * LaunchToken(token).revenueBps() / 10_000;
        bnbOut = gross - platformFee - revenue;
    }

    function sell(uint256 tokenIn, uint256 minBNB, uint256 deadline, address recipient)
        external
        nonReentrant
    {
        if (block.timestamp > deadline) revert Deadline();
        if (graduated) revert Graduated();
        if (recipient == address(0)) revert InvalidConfig();
        (uint256 out, uint256 fee, uint256 revenue, uint256 burned) = quoteSell(tokenIn);
        if (out == 0) revert InvalidAmount();
        if (out < minBNB) revert Slippage();
        IERC20(token).safeTransferFrom(msg.sender, address(this), tokenIn);
        reserveTokens += tokenIn - burned;
        reserveBNB -= out + fee + revenue;
        platformCredit += fee;
        volumeBNB += out + fee + revenue;
        tradeCount++;
        if (burned != 0) LaunchToken(token).burn(burned);
        if (revenue != 0) IRewardVault(vault).notifyBNB{value: revenue}();
        _send(recipient, out);
        emit Trade(
            msg.sender,
            false,
            out,
            tokenIn,
            (out + fee + revenue) * 1e18 / (tokenIn - burned),
            reserveBNB,
            burned
        );
    }

    /// @notice Graduation is a separate public action. DEX problems never roll back the last buy.
    /// Uses the pair directly to tolerate pre-seeded WBNB / sync griefing. Tokens cannot enter a pair before graduation.
    function graduate() external nonReentrant {
        if (graduated) revert Graduated();
        if (reserveBNB < TARGET) revert NotReady();
        address wbnb = IV2Router(router).WETH();
        address factory = IV2Router(router).factory();
        address pair_ = IV2Factory(factory).getPair(token, wbnb);
        if (pair_ == address(0)) pair_ = IV2Factory(factory).createPair(token, wbnb);
        // No genuine LP can exist before token transfers are enabled.
        if (IV2Pair(pair_).totalSupply() != 0) revert InvalidConfig();
        graduated = true;
        pair = pair_;
        uint256 bnb = reserveBNB;
        uint256 tokenAmount = bnb * reserveTokens / (VIRTUAL_BNB + bnb);
        uint256 available = IERC20(token).balanceOf(address(this));
        if (available > tokenAmount) LaunchToken(token).burn(available - tokenAmount);
        LaunchToken(token).activatePair(pair_);
        IERC20(token).safeTransfer(pair_, tokenAmount);
        IWBNB(wbnb).deposit{value: bnb}();
        if (!IWBNB(wbnb).transfer(pair_, bnb)) revert TransferFailed();
        uint256 lp = IV2Pair(pair_).mint(address(0xdead));
        emit Graduation(token, pair_, bnb, tokenAmount, lp);
    }

    function claimPlatform() external nonReentrant {
        uint256 amount = platformCredit;
        if (amount == 0) revert InvalidAmount();
        platformCredit = 0;
        _send(treasury, amount);
        emit PlatformClaimed(amount);
    }

    function _send(address to, uint256 value) internal {
        (bool ok,) = to.call{value: value}("");
        if (!ok) revert TransferFailed();
    }
}
