// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

interface IV2Factory {
    function getPair(address, address) external view returns (address);
    function createPair(address, address) external returns (address);
}

interface IV2Pair {
    function token0() external view returns (address);
    function getReserves() external view returns (uint112, uint112, uint32);
    function totalSupply() external view returns (uint256);
    function mint(address) external returns (uint256);
}

interface IV2Router {
    function factory() external view returns (address);
    function WETH() external view returns (address);
}

interface IWBNB {
    function deposit() external payable;
    function transfer(address, uint256) external returns (bool);
}

interface IRewardVault {
    function notifyBNB() external payable;
    function depositReward(address asset, uint256 amount) external;
}

interface IDividendTracker {
    function syncBalances(address from, uint256 fromBalance, address to, uint256 toBalance) external;
    function setPair(address pair) external;
}

interface IBuybackToken {
    function burn(uint256 amount) external;
}

interface IBuybackPool {
    function buy(uint256 minTokens, uint256 deadline, address recipient) external payable;
}

interface IBuybackRouter {
    function WETH() external view returns (address);
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256, address[] calldata, address, uint256)
        external
        payable;
}
