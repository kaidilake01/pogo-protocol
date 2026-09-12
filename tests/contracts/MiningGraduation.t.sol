// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {StandardCurveTest} from "./StandardCurve.t.sol";
import {QuoteMock,PriceMock} from "./QuoteAssets.t.sol";
import {QuoteAssetRegistryV5} from "../../contracts/internal/QuoteAssetRegistryV5.sol";
import {QuoteAssetRegistry} from "../../contracts/internal/QuoteAssetRegistry.sol";
import {LaunchFactoryV3} from "../../contracts/internal/LaunchFactoryV3.sol";
import {LaunchFactoryV7} from "../../contracts/internal/LaunchFactoryV7.sol";
import {MiningCurve} from "../../contracts/internal/MiningCurve.sol";
import {MiningCurveDeployer} from "../../contracts/internal/MiningCurveDeployer.sol";
import {MiningRevenueVault,MiningVaultDeployer} from "../../contracts/internal/MiningRevenueVault.sol";
import {LaunchMining,LaunchMiningDeployer} from "../../contracts/internal/LaunchMining.sol";
import {StandardLaunchToken} from "../../contracts/src/LaunchToken.sol";
import {StandardCurve} from "../../contracts/internal/StandardCurve.sol";
import {IPancakeMigrationTest} from "./GraduationTarget.t.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LaunchTypes} from "../../contracts/internal/LaunchTypes.sol";

contract MiningGraduationTest is StandardCurveTest {
    function install() internal returns(QuoteAssetRegistryV5 next) {
        next=new QuoteAssetRegistryV5(address(registry));
        LaunchMiningDeployer m=new LaunchMiningDeployer();
        MiningCurveDeployer c=new MiningCurveDeployer(address(f),address(m));
        MiningVaultDeployer v=new MiningVaultDeployer(address(f));
        f.upgradeToAndCall(address(new LaunchFactoryV7()),abi.encodeCall(LaunchFactoryV7.configureMiningLaunches,(address(next),address(c),address(v))));
    }
    function miningLaunch(address asset,bool taxed) internal returns(StandardLaunchToken t,MiningCurve c,MiningRevenueVault v,LaunchMining m) {
        QuoteAssetRegistryV5 next=install();LaunchFactoryV3.CreateParamsV3 memory p=params(asset,taxed);
        p.minTarget=next.quoteLaunch(asset).target;p.maxTarget=p.minTarget;
        t=StandardLaunchToken(f.createTokenV3(p));(,address pool,address vault,)=f.projects(address(t));
        c=MiningCurve(pool);v=MiningRevenueVault(payable(vault));m=LaunchMining(c.stakingPool());
    }
    function testMiningOriginalPriceEarlyGraduationAndActualRemainder() public {
        (StandardLaunchToken oldT,StandardCurve oldC,)=launch(address(0),false);
        (StandardLaunchToken t,MiningCurve c,,LaunchMining m)=miningLaunch(address(0),false);
        assertEq(c.spotPrice(),oldC.spotPrice());assertEq(c.virtualQuote(),oldC.virtualQuote());
        assertEq(c.graduationTarget(),6.666 ether);assertEq(oldC.graduationTarget(),18 ether);assertEq(f.CREATION_FEE(),0);
        oldC.buy{value:.1 ether}(.1 ether,1,block.timestamp,address(this));c.buy{value:.1 ether}(.1 ether,1,block.timestamp,address(this));
        // Original target-dependent integer ceiling differs by sub-nanotoken dust.
        assertApprox(t.balanceOf(address(this)),oldT.balanceOf(address(this)),1e9);assertEq(c.spotPrice(),oldC.spotPrice());
        c.buy{value:10 ether}(10 ether,1,block.timestamp,address(this));uint256 finalPrice=c.spotPrice();
        assertEq(c.reserveQuote(),6.666 ether);assertEq(c.progressBps(),10000);assertEq(t.launchPair().code.length,0);
        uint256 sold=t.balanceOf(address(this));assertTrue(sold>557_000_000 ether&&sold<559_000_000 ether);
        c.graduate();uint256 seed=t.balanceOf(c.pair());
        assertApprox(finalPrice,uint256(6.53268 ether)*1e18/seed,1);
        assertEq(m.rewardBudget(),1_000_000_000 ether-sold-seed);assertEq(t.balanceOf(address(c)),m.rewardBudget());
        assertTrue(m.rewardBudget()>179_000_000 ether&&m.rewardBudget()<180_000_000 ether);
        assertEq(t.balanceOf(address(m)),0);assertEq(t.totalSupply(),1_000_000_000 ether);assertEq(t.owner(),address(0));
        assertTrue(IERC20(c.pair()).balanceOf(address(0xdead))>0);
        assertEq(m.endsAt(),0);assertEq(m.DURATION(),30 days);assertTrue(c.stakingPriceUSD()>0);
    }
    function testMiningStakedPrincipalKeepsDividendsAndReserveExcluded() public {
        (StandardLaunchToken t,MiningCurve c,MiningRevenueVault v,LaunchMining m)=miningLaunch(address(0),true);
        c.buy{value:10 ether}(10 ether,1,block.timestamp,address(this));c.graduate();
        uint256 before_=t.balanceOf(address(this));uint256 eligible=v.eligibleSupply();
        t.approve(address(m),type(uint256).max);m.stake(100_000 ether,true);
        assertEq(v.holderBalance(address(this)),before_);assertEq(v.eligibleSupply(),eligible);
        assertEq(v.holderBalance(address(m)),0);assertEq(v.holderBalance(address(c)),0);
        uint256 prior=v.earned(address(this),address(0));vm.deal(address(c),address(c).balance+1 ether);vm.prank(address(c));v.notifyQuote{value:1 ether}(1 ether);
        assertTrue(v.earned(address(this),address(0))>prior);
        vm.warp(m.startedAt()+1 days);m.claimFor(address(this));
        assertEq(v.holderBalance(address(this)),t.balanceOf(address(this))+m.balanceOf(address(this)));
        m.withdrawLocked(0,100_000 ether);assertEq(v.holderBalance(address(this)),t.balanceOf(address(this)));
        assertEq(t.balanceOf(address(m)),0);assertEq(c.miningReleased(),m.claimedRewards());
        vm.expectRevert(MiningCurve.InvalidConfig.selector);c.releaseMiningReward(address(this),1);
    }
    function testMiningStockTargetAndSixDecimalEntryPrice() public {
        QuoteMock stable=new QuoteMock(6);
        PriceMock feed=new PriceMock();feed.set(1e8,block.timestamp);
        registry.configure(address(stable),QuoteAssetRegistry.Asset(address(feed),0,3600,6,8,0,true));
        (StandardLaunchToken t,MiningCurve c,,LaunchMining m)=miningLaunch(address(stable),false);
        stable.mint(address(this),10_000e6);stable.approve(address(c),type(uint256).max);
        c.buy(10_000e6,1,block.timestamp,address(this));c.graduate();
        assertTrue(c.stakingPriceUSD()>0);t.approve(address(m),type(uint256).max);m.stake(1_000_000 ether,false);
        assertTrue(m.entryCostUSD(address(this))>1 ether);assertEq(m.unpricedBalance(address(this)),0);
    }
    function testMiningStockKeepsOpeningQuoteAndMinesActualBalance() public {
        uint256 oldQ=registry.quoteLaunch(address(quote)).virtualQuote;
        (StandardLaunchToken t,MiningCurve c,,LaunchMining m)=miningLaunch(address(quote),false);
        assertEq(c.virtualQuote(),oldQ);assertEq(c.graduationTarget(),33.33 ether);
        quote.mint(address(this),100 ether);quote.approve(address(c),type(uint256).max);c.buy(100 ether,1,block.timestamp,address(this));c.graduate();
        assertEq(quote.balanceOf(c.pair()),32.6634 ether);assertEq(t.balanceOf(address(c)),m.rewardBudget());
    }
    function testMiningForkRealPancakeAndDividendExit() public {
        if(vm.envOr("RUN_BSC_FORK",uint256(0))==0){vm.skip(true);return;}
        vm.createSelectFork(vm.envOr("BSC_RPC_URL",string("https://bsc-dataseed.bnbchain.org")));
        vm.deal(address(this),20 ether);
        LaunchFactoryV7 live=LaunchFactoryV7(payable(0x0abc6174ee9f9600243D14F83E215993b8BbABEb));
        QuoteAssetRegistryV5 next=new QuoteAssetRegistryV5(0xaa882B7d53eC9d028f877C5c5202ab2faB1EcD46);
        LaunchMiningDeployer md=new LaunchMiningDeployer();MiningCurveDeployer cd=new MiningCurveDeployer(address(live),address(md));
        MiningVaultDeployer vd=new MiningVaultDeployer(address(live));LaunchFactoryV7 implementation=new LaunchFactoryV7();
        vm.prank(live.owner());live.upgradeToAndCall(address(implementation),abi.encodeCall(LaunchFactoryV7.configureMiningLaunches,(address(next),address(cd),address(vd))));
        LaunchFactoryV3.CreateParamsV3 memory p;p.name="Mining fork";p.symbol="MINE";p.metadataURI="ipfs://test";
        p.expectedConfig=live.launchConfigHash(address(0));p.minTarget=6.666 ether;p.maxTarget=p.minTarget;
        p.tax=LaunchTypes.Tax(300,300,4000,2000,3000,1000,address(this),0);
        (address deployer,bytes32 hash)=live.tokenDeploymentConfig();
        for(uint256 i;;i++){
            uint256 free;assembly("memory-safe"){free:=mload(0x40)}p.salt=bytes32(i);
            address predicted=address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff),deployer,keccak256(abi.encode(address(this),p.salt)),hash)))));
            assembly("memory-safe"){mstore(0x40,free)}if(uint160(predicted)&0xffff==0x6666&&predicted.code.length==0)break;
        }
        uint256 gasBefore=gasleft();address token=live.createTokenV3(p);assertTrue(gasBefore-gasleft()<15_000_000);
        (,address pool,address vault,)=live.projects(token);MiningCurve c=MiningCurve(pool);LaunchMining m=LaunchMining(c.stakingPool());
        c.buy{value:10 ether}(10 ether,1,block.timestamp,address(this));c.graduate();
        assertEq(c.graduationTarget(),6.666 ether);assertTrue(IERC20(c.pair()).balanceOf(address(0xdead))>0);
        IERC20(token).approve(address(m),type(uint256).max);m.stake(1_000_000 ether,true);assertTrue(m.entryCostUSD(address(this))>0);
        IPancakeMigrationTest pancake=IPancakeMigrationTest(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address[] memory path=new address[](2);path[0]=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;path[1]=token;
        uint256 beforeTokens=IERC20(token).balanceOf(address(this));
        pancake.swapExactETHForTokensSupportingFeeOnTransferTokens{value:.01 ether}(1,path,address(this),block.timestamp);
        uint256 received=IERC20(token).balanceOf(address(this))-beforeTokens;assertTrue(received>0);
        IERC20(token).approve(address(pancake),received);path[0]=token;path[1]=pancake.WETH();
        pancake.swapExactTokensForETHSupportingFeeOnTransferTokens(received,1,path,address(this),block.timestamp);
        vm.warp(m.startedAt()+6 hours);m.withdrawLocked(0,1_000_000 ether);
        assertEq(m.balanceOf(address(this)),0);assertTrue(m.claimedRewards()>0);
        assertEq(MiningRevenueVault(payable(vault)).holderBalance(address(this)),IERC20(token).balanceOf(address(this)));
    }
}
