// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
contract QuoteMock is ERC20 {
    uint8 private immutable dp;
    constructor(uint8 decimals_) ERC20("Stock quote", "STOCK") { dp=decimals_; }
    function decimals() public view override returns(uint8) { return dp; }
    function mint(address to,uint256 amount) external { _mint(to,amount); }
}
contract PriceMock {
    uint8 public decimals=8;
    int256 public answer=700e8;
    uint256 public timestamp;
    bool public eoaOnly;
    constructor() { timestamp=block.timestamp; }
    function set(int256 a,uint256 t) external { answer=a; timestamp=t; }
    function setRestricted() external { eoaOnly=true; }
    function latestRoundData() external view returns(uint80,int256,uint256,uint256,uint80) {
        require(!eoaOnly || msg.sender==tx.origin,"EOA_ONLY");
        return(1,answer,timestamp,timestamp,1);
    }
}
