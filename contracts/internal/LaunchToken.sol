// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IRewardVault, IDividendTracker} from "./Interfaces.sol";

/// @notice Fixed-supply, immutable-fee launch token. Clone implementation has no upgrade path.
contract LaunchToken is ERC20, ReentrancyGuard {
    uint256 public constant INITIAL_SUPPLY = 1_000_000_000 ether;
    address public pool;
    address public vault;
    address public pair;
    address public launchPair;
    uint16 public revenueBps;
    uint16 public burnBps;
    uint8 public rewardMode;
    uint8 public burnMode;
    bool private initialized;
    string private tokenName;
    string private tokenSymbol;
    string public metadataURI;
    uint256 public totalBurned;

    error AlreadyInitialized();
    error Unauthorized();
    error InvalidConfig();
    error CurveTransfersRestricted();
    event FeesDistributed(uint256 amount);
    event TokensBurned(address indexed account, uint256 amount);
    event PairActivated(address indexed pair);

    constructor() ERC20("", "") {
        initialized = true;
    }

    struct Init {
        string name;
        string symbol;
        string uri;
        address pool;
        address vault;
        uint16 revenue;
        uint16 burn;
        uint8 rewards;
        uint8 burns;
    }

    function initialize(Init calldata p) external {
        if (initialized) revert AlreadyInitialized();
        if (p.pool == address(0) || p.vault == address(0) || p.revenue > 500 || p.burn > 200) {
            revert InvalidConfig();
        }
        initialized = true;
        tokenName = p.name;
        tokenSymbol = p.symbol;
        metadataURI = p.uri;
        pool = p.pool;
        vault = p.vault;
        revenueBps = p.revenue;
        burnBps = p.burn;
        rewardMode = p.rewards;
        burnMode = p.burns;
        _mint(p.pool, INITIAL_SUPPLY);
    }

    function name() public view override returns (string memory) {
        return tokenName;
    }

    function symbol() public view override returns (string memory) {
        return tokenSymbol;
    }

    function activatePair(address pair_) external {
        if (msg.sender != pool || pair != address(0) || pair_ == address(0) || pair_ != launchPair) revert Unauthorized();
        pair = pair_;
        IDividendTracker(vault).setPair(pair_);
        emit PairActivated(pair_);
    }

    function reservePair(address pair_) external {
        if (msg.sender != pool || launchPair != address(0) || pair_.code.length == 0) revert Unauthorized();
        launchPair = pair_;
    }

    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
        totalBurned += amount;
        emit TokensBurned(msg.sender, amount);
    }

    /// @notice Permissionless settlement, without a swap or price-taking keeper.
    /// External-pool revenue is distributed in this token; curve revenue is BNB.
    function distributeFees() external nonReentrant {
        uint256 amount = balanceOf(address(this));
        if (amount == 0) revert InvalidConfig();
        _approve(address(this), vault, amount);
        IRewardVault(vault).depositReward(address(this), amount);
        _approve(address(this), vault, 0);
        emit FeesDistributed(amount);
    }

    function _update(address from, address to, uint256 value) internal override {
        if (pair == address(0) && launchPair != address(0) && to == launchPair) revert CurveTransfersRestricted();
        // Prevent external price pools being funded before graduation. Wallets can trade and claim.
        if (
            pair == address(0) && from != address(0) && to != address(0) && from != pool && to != pool
                && from != vault && to != vault && from != address(this)
        ) {
            revert CurveTransfersRestricted();
        }
        if (
            pair != address(0) && (from == pair || to == pair) && from != pool && to != pool
                && from != address(this)
        ) {
            uint256 fee = value * revenueBps / 10_000;
            uint256 burned = value * burnBps / 10_000;
            if (fee != 0) _move(from, address(this), fee);
            if (burned != 0) {
                _move(from, address(0), burned);
                totalBurned += burned;
                emit TokensBurned(from, burned);
            }
            value -= fee + burned;
        }
        _move(from, to, value);
    }

    function _move(address from, address to, uint256 value) internal {
        super._update(from, to, value);
        IDividendTracker(vault).syncBalances(from, balanceOf(from), to, balanceOf(to));
    }
}
