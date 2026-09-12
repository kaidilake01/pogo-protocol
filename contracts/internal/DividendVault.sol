// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IBuybackToken, IBuybackPool, IBuybackRouter} from "./Interfaces.sol";

/// @notice Wallet-balance dividends. No deposits of principal, stake, withdrawal or lock periods.
contract DividendVault is ReentrancyGuard {
    using SafeERC20 for IERC20;
    uint256 private constant SCALE = 1e36;
    address public token;
    address public creator;
    address public pool;
    address public pair;
    address public router;
    address public extraAsset;
    uint16 public holderShareBps;
    uint16 public buybackShareBps;
    uint256 public eligibleSupply;
    uint256 public buybackBNB;
    uint256 public totalBuybackBurned;
    bool private initialized;
    mapping(address => uint256) public holderBalance;
    mapping(address => uint256) public accPerShare;
    mapping(address => uint256) public queued;
    mapping(address => uint256) public totalDistributed;
    mapping(address => uint256) public creatorCredit;
    mapping(address => mapping(address => uint256)) public paid;
    mapping(address => mapping(address => uint256)) public credit;
    error InvalidConfig();
    error Unauthorized();
    error InvalidAmount();
    error TransferFailed();
    event RewardAdded(address indexed asset, uint256 holders, uint256 creator, uint256 burnAllocation);
    event Claimed(address indexed user, address indexed asset, uint256 amount);
    event CreatorClaimed(address indexed asset, uint256 amount);
    event BuybackExecuted(address indexed caller, uint256 bnb, uint256 burned, bool externalMarket);

    constructor() {
        initialized = true;
    }

    function initialize(
        address token_,
        address creator_,
        address pool_,
        address router_,
        address extra_,
        uint16 holders_,
        uint16 buyback_
    ) external {
        if (
            initialized || token_ == address(0) || creator_ == address(0) || pool_ == address(0)
                || router_ == address(0) || extra_ == token_ || uint256(holders_) + buyback_ > 10000
        ) revert InvalidConfig();
        initialized = true;
        token = token_;
        creator = creator_;
        pool = pool_;
        router = router_;
        extraAsset = extra_;
        holderShareBps = holders_;
        buybackShareBps = buyback_;
    }

    function validAsset(address asset) public view returns (bool) {
        return asset == address(0) || asset == token || (extraAsset != address(0) && asset == extraAsset);
    }

    function eligible(address user) public view returns (bool) {
        return
            user != address(0) && user != address(0xdead) && user != token && user != address(this)
                && user != pool && user != pair;
    }

    function _settle(address user, address asset) internal {
        credit[user][asset] += Math.mulDiv(holderBalance[user], accPerShare[asset] - paid[user][asset], SCALE);
        paid[user][asset] = accPerShare[asset];
    }

    function _sync(address user, uint256 balance) internal {
        if (!eligible(user)) return;
        _settle(user, address(0));
        _settle(user, token);
        if (extraAsset != address(0)) _settle(user, extraAsset);
        eligibleSupply = eligibleSupply - holderBalance[user] + balance;
        holderBalance[user] = balance;
    }

    // Only the immutable launch token can update snapshots. This hook intentionally permits
    // reward payouts to synchronize token balances while a guarded claim is in progress.
    function syncBalances(address from, uint256 fromBalance, address to, uint256 toBalance) external {
        if (msg.sender != token) revert Unauthorized();
        _sync(from, fromBalance);
        if (to != from) _sync(to, toBalance);
    }

    function setPair(address pair_) external {
        if (msg.sender != token || pair != address(0) || pair_ == address(0)) revert Unauthorized();
        _sync(pair_, 0);
        pair = pair_;
    }

    function earned(address user, address asset) public view returns (uint256) {
        return
            credit[user][asset]
                + Math.mulDiv(holderBalance[user], accPerShare[asset] - paid[user][asset], SCALE);
    }

    function _allocate(address asset, uint256 amount) internal {
        amount += queued[asset];
        if (eligibleSupply == 0) {
            queued[asset] = amount;
            return;
        }
        uint256 increment = Math.mulDiv(amount, SCALE, eligibleSupply);
        // Round down the paid-per-share value; the sub-wei distribution difference remains
        // unallocated. Never re-credit it, which would pay the same dust repeatedly.
        accPerShare[asset] += increment;
        queued[asset] = 0;
        totalDistributed[asset] += amount;
    }

    function distributeQueued(address asset) external nonReentrant {
        if (!validAsset(asset) || queued[asset] == 0 || eligibleSupply == 0) revert InvalidAmount();
        _allocate(asset, 0);
    }

    // BNB notifications do not make external calls, and may occur inside a curve buyback.
    function notifyBNB() external payable {
        if (msg.value == 0) revert InvalidAmount();
        _addReward(address(0), msg.value, true);
    }

    function depositReward(address asset, uint256 amount) external nonReentrant {
        if (asset == address(0) || !validAsset(asset) || amount == 0) revert InvalidConfig();
        uint256 before_ = IERC20(asset).balanceOf(address(this));
        IERC20(asset).safeTransferFrom(msg.sender, address(this), amount);
        uint256 received = IERC20(asset).balanceOf(address(this)) - before_;
        if (received == 0) revert InvalidAmount();
        _addReward(asset, received, asset == token);
    }

    function _addReward(address asset, uint256 amount, bool split) internal {
        uint256 holders = split ? amount * holderShareBps / 10000 : amount;
        uint256 burnAllocation = split ? amount * buybackShareBps / 10000 : 0;
        creatorCredit[asset] += amount - holders - burnAllocation;
        if (asset == address(0)) {
            buybackBNB += burnAllocation;
        } else if (burnAllocation != 0) {
            IBuybackToken(token).burn(burnAllocation);
            totalBuybackBurned += burnAllocation;
        }
        if (holders != 0 || queued[asset] != 0) _allocate(asset, holders);
        emit RewardAdded(asset, holders, amount - holders - burnAllocation, burnAllocation);
    }

    function claim(address asset, address recipient) external nonReentrant {
        if (!validAsset(asset) || recipient == address(0)) revert InvalidConfig();
        _settle(msg.sender, asset);
        uint256 amount = credit[msg.sender][asset];
        if (amount == 0) revert InvalidAmount();
        credit[msg.sender][asset] = 0;
        _send(asset, recipient, amount);
        emit Claimed(msg.sender, asset, amount);
    }

    function claimCreator(address asset, address recipient) external nonReentrant {
        if (msg.sender != creator || recipient == address(0) || !validAsset(asset)) revert Unauthorized();
        uint256 amount = creatorCredit[asset];
        if (amount == 0) revert InvalidAmount();
        creatorCredit[asset] = 0;
        _send(asset, recipient, amount);
        emit CreatorClaimed(asset, amount);
    }

    function executeBuyback(uint256 amount, uint256 minTokens, uint256 deadline) external nonReentrant {
        if (msg.sender != creator) revert Unauthorized();
        if (amount == 0 || amount > buybackBNB || minTokens == 0 || block.timestamp > deadline) revert InvalidAmount();
        buybackBNB -= amount;
        uint256 before_ = IERC20(token).balanceOf(address(this));
        bool externalMarket = pair != address(0);
        if (externalMarket) {
            address[] memory path = new address[](2);
            path[0] = IBuybackRouter(router).WETH();
            path[1] = token;
            IBuybackRouter(router).swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
                minTokens, path, address(this), deadline
            );
        } else {
            IBuybackPool(pool).buy{value: amount}(minTokens, deadline, address(this));
        }
        uint256 received = IERC20(token).balanceOf(address(this)) - before_;
        if (received < minTokens) revert InvalidAmount();
        IBuybackToken(token).burn(received);
        totalBuybackBurned += received;
        emit BuybackExecuted(msg.sender, amount, received, externalMarket);
    }

    receive() external payable {
        if (msg.sender != pool) revert Unauthorized();
        buybackBNB += msg.value;
    }

    function _send(address asset, address recipient, uint256 amount) internal {
        if (asset == token && pair == address(0) && recipient != msg.sender) revert InvalidConfig();
        if (asset == address(0)) {
            (bool ok,) = recipient.call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else {
            IERC20(asset).safeTransfer(recipient, amount);
        }
    }
}
