// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {LaunchTypes,IRevenueVaultV3} from "./LaunchTypes.sol";
import {RevenueVault} from "./RevenueVault.sol";

contract LaunchTokenV3 is ERC20,ReentrancyGuard {
    uint256 public constant VERSION=3;
    uint256 public constant INITIAL_SUPPLY=1_000_000_000 ether;
    address public pool;
    address public vault;
    address public pair;
    address public launchPair;
    uint16 public buyTaxBps;
    uint16 public sellTaxBps;
    uint256 public totalBurned;
    string public metadataURI;
    string private tokenName;
    string private tokenSymbol;
    bool internal initialized;
    bool private distributing;
    error InvalidConfig();error Unauthorized();error CurveTransfersRestricted();
    event PairActivated(address indexed pair);
    event FeesDistributed(uint256 amount);
    event TokensBurned(address indexed account,uint256 amount);
    struct Init {string name;string symbol;string uri;address pool;address vault;uint16 buyTaxBps;uint16 sellTaxBps;}
    constructor() ERC20("",""){initialized=true;}
    function initialize(Init calldata p) public virtual {
        if(initialized||p.pool.code.length==0||p.vault.code.length==0||p.buyTaxBps>500||p.sellTaxBps>500)revert InvalidConfig();
        initialized=true;tokenName=p.name;tokenSymbol=p.symbol;metadataURI=p.uri;
        pool=p.pool;vault=p.vault;buyTaxBps=p.buyTaxBps;sellTaxBps=p.sellTaxBps;
        _mint(pool,INITIAL_SUPPLY);
    }
    function name() public view override returns(string memory){return tokenName;}
    function symbol() public view override returns(string memory){return tokenSymbol;}
    function activatePair(address p) external {
        if(msg.sender!=pool||pair!=address(0)||p==address(0)||p!=launchPair)revert Unauthorized();
        pair=p;IRevenueVaultV3(vault).setPair(p);emit PairActivated(p);
    }
    function reservePair(address p) external virtual {
        if(msg.sender!=pool||launchPair!=address(0)||p.code.length==0)revert Unauthorized();
        launchPair=p;
    }
    function burn(uint256 amount) external {
        _burn(msg.sender,amount);totalBurned+=amount;emit TokensBurned(msg.sender,amount);
    }
    function distributeFees() external nonReentrant {
        uint256 amount=balanceOf(address(this));if(amount==0)revert InvalidConfig();
        distributing=true;
        _approve(address(this),vault,amount);
        RevenueVault(payable(vault)).depositTokenRevenue(amount);
        _approve(address(this),vault,0);
        distributing=false;emit FeesDistributed(amount);
    }
    function _update(address from,address to,uint256 amount) internal override {
        // Applies even to curve buys, vault payouts and token-contract transfers.
        if(pair==address(0)&&launchPair!=address(0)&&to==launchPair)revert CurveTransfersRestricted();
        if(pair==address(0)&&from!=address(0)&&to!=address(0)&&from!=pool&&to!=pool&&from!=vault&&to!=vault&&from!=address(this))revert CurveTransfersRestricted();
        bool taxed=pair!=address(0)&&(from==pair||to==pair)&&from!=pool&&to!=pool&&from!=vault&&to!=vault&&from!=address(this);
        if(taxed){
            uint256 fee=amount*(from==pair?buyTaxBps:sellTaxBps)/10_000;
            if(fee!=0){_move(from,address(this),fee);amount-=fee;}
        }
        _move(from,to,amount);
        // No swap inside a pair's lock. Revenue settles in the launch token, explicitly shown in the UI.
        // Automatic distribution is isolated; a recipient failing cannot make a token unsellable.
        if(taxed&&!distributing&&balanceOf(address(this))!=0){try this.distributeFees{gas:650_000}(){}catch{}}
    }
    function _move(address from,address to,uint256 value) private {
        super._update(from,to,value);
        IRevenueVaultV3(vault).syncBalances(from,balanceOf(from),to,balanceOf(to));
    }
}
