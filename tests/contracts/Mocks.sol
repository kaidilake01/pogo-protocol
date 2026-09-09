// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";

contract MockAsset is ERC20 {
    bool public blocked;
    constructor() ERC20("Test Asset", "TASSET") {}

    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }

    function setBlocked(bool value) external {
        blocked = value;
    }

    function _update(address from, address to, uint256 amount) internal override {
        require(!blocked, "ASSET_BLOCKED");
        super._update(from, to, amount);
    }
}

contract MockWBNB is ERC20 {
    constructor() ERC20("Wrapped BNB", "WBNB") {}

    function deposit() external payable {
        _mint(msg.sender, msg.value);
    }

    function withdraw(uint256 value) external {
        _burn(msg.sender, value);
        (bool ok,) = msg.sender.call{value: value}("");
        require(ok);
    }
}

contract MockPair is ERC20 {
    address public token0;
    address public token1;
    uint112 private reserve0;
    uint112 private reserve1;
    uint32 private reserveTimestamp;
    uint256 public price0CumulativeLast;
    uint256 public price1CumulativeLast;
    event Swap(
        address indexed sender,
        uint256 amount0In,
        uint256 amount1In,
        uint256 amount0Out,
        uint256 amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    constructor(address a, address b) ERC20("Pancake LP", "Cake-LP") {
        token0 = a < b ? a : b;
        token1 = a < b ? b : a;
    }

    function getReserves() external view returns (uint112, uint112, uint32) {
        return (reserve0, reserve1, reserveTimestamp);
    }

    function sync() public {
        unchecked {
            uint32 elapsed=uint32(block.timestamp)-reserveTimestamp;
            if(reserve0!=0&&reserve1!=0){
                price0CumulativeLast+=(uint256(reserve1)*2**112/reserve0)*elapsed;
                price1CumulativeLast+=(uint256(reserve0)*2**112/reserve1)*elapsed;
            }
        }
        reserveTimestamp=uint32(block.timestamp);
        reserve0 = uint112(IERC20(token0).balanceOf(address(this)));
        reserve1 = uint112(IERC20(token1).balanceOf(address(this)));
        emit Sync(reserve0, reserve1);
    }

    function mint(address to) external returns (uint256 liquidity) {
        uint256 a = IERC20(token0).balanceOf(address(this)) - reserve0;
        uint256 b = IERC20(token1).balanceOf(address(this)) - reserve1;
        if (totalSupply() == 0) {
            liquidity = Math.sqrt(a * b) - 1000;
            _mint(address(0xdead), 1000);
        } else {
            liquidity = Math.min(a * totalSupply() / reserve0, b * totalSupply() / reserve1);
        }
        require(liquidity > 0, "LIQUIDITY");
        _mint(to, liquidity);
        sync();
    }

    function swap(uint256 a0Out, uint256 a1Out, address to, bytes calldata) external {
        require(a0Out > 0 || a1Out > 0, "ZERO_OUTPUT");
        require(a0Out < reserve0 && a1Out < reserve1, "RESERVES");
        if (a0Out != 0) require(IERC20(token0).transfer(to, a0Out));
        if (a1Out != 0) require(IERC20(token1).transfer(to, a1Out));
        uint256 b0 = IERC20(token0).balanceOf(address(this));
        uint256 b1 = IERC20(token1).balanceOf(address(this));
        uint256 a0In = b0 > reserve0 - a0Out ? b0 - (reserve0 - a0Out) : 0;
        uint256 a1In = b1 > reserve1 - a1Out ? b1 - (reserve1 - a1Out) : 0;
        require(
            (b0 * 10000 - a0In * 25) * (b1 * 10000 - a1In * 25) >= uint256(reserve0) * reserve1 * 1e8, "K"
        );
        emit Swap(msg.sender, a0In, a1In, a0Out, a1Out, to);
        sync();
    }
}

contract MockV2Factory {
    mapping(address => mapping(address => address)) public getPair;

    function createPair(address a, address b) external returns (address pair) {
        require(a != b && getPair[a][b] == address(0));
        pair = address(new MockPair(a, b));
        getPair[a][b] = pair;
        getPair[b][a] = pair;
    }
}

contract MockRouter {
    address public WETH;
    address public factory;

    constructor(address wbnb, address factory_) {
        WETH = wbnb;
        factory = factory_;
    }

    receive() external payable {
        require(msg.sender == WETH);
    }

    function getAmountsOut(uint256 amount, address[] calldata path)
        external
        view
        returns (uint256[] memory amounts)
    {
        require(path.length == 2);
        amounts = new uint256[](2);
        amounts[0] = amount;
        MockPair pair = MockPair(MockV2Factory(factory).getPair(path[0], path[1]));
        (uint112 r0, uint112 r1,) = pair.getReserves();
        (uint256 rIn, uint256 rOut) = pair.token0() == path[0] ? (r0, r1) : (r1, r0);
        amounts[1] = amount * 9975 * rOut / (rIn * 10000 + amount * 9975);
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 minimum,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable {
        require(block.timestamp <= deadline && path[0] == WETH && path.length == 2);
        MockPair pair = MockPair(MockV2Factory(factory).getPair(path[0], path[1]));
        uint256 before_ = IERC20(path[1]).balanceOf(to);
        MockWBNB(WETH).deposit{value: msg.value}();
        IERC20(WETH).transfer(address(pair), msg.value);
        _swap(pair, WETH, to);
        require(IERC20(path[1]).balanceOf(to) - before_ >= minimum, "SLIPPAGE");
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amount,
        uint256 minimum,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external {
        require(block.timestamp <= deadline && path[1] == WETH && path.length == 2);
        MockPair pair = MockPair(MockV2Factory(factory).getPair(path[0], path[1]));
        uint256 before_ = IERC20(WETH).balanceOf(address(this));
        IERC20(path[0]).transferFrom(msg.sender, address(pair), amount);
        _swap(pair, path[0], address(this));
        uint256 out = IERC20(WETH).balanceOf(address(this)) - before_;
        require(out >= minimum, "SLIPPAGE");
        MockWBNB(WETH).withdraw(out);
        (bool ok,) = to.call{value: out}("");
        require(ok);
    }

    function _swap(MockPair pair, address input, address to) internal {
        (uint112 r0, uint112 r1,) = pair.getReserves();
        bool first = pair.token0() == input;
        (uint256 rIn, uint256 rOut) = first ? (r0, r1) : (r1, r0);
        uint256 amount = IERC20(input).balanceOf(address(pair)) - rIn;
        uint256 output = amount * 9975 * rOut / (rIn * 10000 + amount * 9975);
        pair.swap(first ? 0 : output, first ? output : 0, to, "");
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(uint256 amount,uint256 minimum,address[] calldata path,address to,uint256 deadline) external {
        require(block.timestamp<=deadline&&path.length==2);
        MockPair pair=MockPair(MockV2Factory(factory).getPair(path[0],path[1]));
        uint256 before_=IERC20(path[1]).balanceOf(to);
        require(IERC20(path[0]).transferFrom(msg.sender,address(pair),amount));
        _swap(pair,path[0],to);
        require(IERC20(path[1]).balanceOf(to)-before_>=minimum,"SLIPPAGE");
    }
}
