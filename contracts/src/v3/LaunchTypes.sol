// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

library LaunchTypes {
    struct Tax {
        uint16 buyBps;
        uint16 sellBps;
        uint16 recipientBps;
        uint16 burnBps;
        uint16 holderBps;
        uint16 liquidityBps;
        address recipient;
        uint256 minimumHolding;
    }
    function valid(Tax memory t) internal pure returns (bool) {
        return t.buyBps <= 500 && t.sellBps <= 500 && t.recipient != address(0)
            && uint256(t.recipientBps) + t.burnBps + t.holderBps + t.liquidityBps == 10_000
            && t.minimumHolding <= 1_000_000_000 ether;
    }
}

interface ILaunchTokenV3 {
    function buyTaxBps() external view returns (uint16);
    function sellTaxBps() external view returns (uint16);
    function burn(uint256 amount) external;
    function activatePair(address pair) external;
    function reservePair(address pair) external;
}
interface IRevenueVaultV3 {
    function notifyQuote(uint256 amount) external payable;
    function syncBalances(address from, uint256 fromBalance, address to, uint256 toBalance) external;
    function setPair(address pair) external;
}
