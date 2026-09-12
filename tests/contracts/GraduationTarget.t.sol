// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;

import {StandardCurveTest} from "./StandardCurve.t.sol";
import {QuoteAssetRegistryV4} from "../../contracts/internal/QuoteAssetRegistryV4.sol";
import {QuoteAssetRegistry} from "../../contracts/internal/QuoteAssetRegistry.sol";
import {LaunchFactoryV3} from "../../contracts/internal/LaunchFactoryV3.sol";
import {LaunchFactoryV6} from "../../contracts/internal/LaunchFactoryV6.sol";
import {StandardCurve} from "../../contracts/internal/StandardCurve.sol";
import {StandardLaunchToken} from "../../contracts/src/LaunchToken.sol";
import {BNBQuoteAdapter} from "../../contracts/src/BNBQuoteAdapter.sol";
import {LaunchTypes} from "../../contracts/internal/LaunchTypes.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IV2Router} from "../../contracts/internal/Interfaces.sol";

interface IPancakeMigrationTest is IV2Router {
    function swapExactETHForTokensSupportingFeeOnTransferTokens(uint256, address[] calldata, address, uint256) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256, uint256, address[] calldata, address, uint256) external;
}

contract GraduationTargetTest is StandardCurveTest {
    function installTestTarget() internal returns (QuoteAssetRegistryV4 next) {
        next = new QuoteAssetRegistryV4(address(this), address(registry), .1 ether);
        f.upgradeToAndCall(address(new LaunchFactoryV6()), "");
        f.configureStandardLaunches(address(next), address(f.standaloneTokenDeployer()), address(f.standaloneCurveDeployer()));
    }
    function testSmallTargetInitialBuyAndKeeperMigration() public {
        QuoteAssetRegistryV4 next = installTestTarget();
        LaunchFactoryV3.CreateParamsV3 memory p = params(address(0), false);
        p.minTarget = next.quoteLaunch(address(0)).target; p.maxTarget = p.minTarget;
        uint256 gross = (p.minTarget * 10000 + 9899) / 9900;
        LaunchFactoryV3.DeveloperBuy memory b = LaunchFactoryV3.DeveloperBuy(gross, 0, 1, block.timestamp, true, BNBQuoteAdapter.Route(0, new address[](0), ""));
        address token = f.createTokenAndBuyV3{value:gross}(p, b);
        (,address pool,,) = f.projects(token); StandardCurve c = StandardCurve(pool);
        assertEq(c.reserveQuote(), .1 ether); assertEq(c.progressBps(), 10000);
        assertEq(StandardLaunchToken(token).totalSupply(), 1_000_000_000 ether);
        assertTrue(!c.graduated()); vm.prank(address(0x999)); c.graduate();
        assertTrue(c.graduated()); assertEq(wrapped.balanceOf(c.pair()), .098 ether);
        assertEq(IERC20(token).balanceOf(c.pair()), 200_000_000 ether);
        assertTrue(IERC20(c.pair()).balanceOf(address(0xdead)) > 0);
        assertEq(f.CREATION_FEE(), 0);
    }
    function testExactPointOnePaymentNeedsFeesAndTaxTopUp() public {
        QuoteAssetRegistryV4 next = installTestTarget();
        LaunchFactoryV3.CreateParamsV3 memory p = params(address(0), true);
        p.minTarget = next.quoteLaunch(address(0)).target; p.maxTarget = p.minTarget;
        address token = f.createTokenV3(p); (,address pool,,) = f.projects(token);
        StandardCurve c = StandardCurve(pool);
        c.buy{value:.1 ether}(.1 ether, 1, block.timestamp, address(this));
        assertEq(c.reserveQuote(), .096 ether); assertTrue(c.progressBps() < 10000);
        vm.expectRevert(StandardCurve.NotReady.selector); c.graduate();
        c.buy{value:.01 ether}(.01 ether, 1, block.timestamp, address(this));
        assertEq(c.reserveQuote(), .1 ether); c.graduate(); assertTrue(c.graduated());
    }
    function testRestoreStandardLeavesTestPoolFrozenAndInvalidatesDraft() public {
        QuoteAssetRegistryV4 next = installTestTarget();
        LaunchFactoryV3.CreateParamsV3 memory p = params(address(0), false);
        p.minTarget = .1 ether; p.maxTarget = p.minTarget;
        address token = f.createTokenV3(p); (,address pool,,) = f.projects(token);
        bytes32 beforeHash = next.configHash(address(0));
        next.setLaunchTargetBNB(18 ether);
        assertEq(next.quoteLaunch(address(0)).target, 18 ether);
        assertEq(StandardCurve(pool).graduationTarget(), .1 ether);
        assertTrue(beforeHash != next.configHash(address(0)));
        vm.expectRevert(); f.createTokenV3(p);
        vm.prank(address(0x999)); vm.expectRevert(); next.setLaunchTargetBNB(.1 ether);
        vm.expectRevert(QuoteAssetRegistryV4.InvalidTarget.selector); next.setLaunchTargetBNB(0);
    }
    function testStockTargetConversionAndForwardedOracle() public {
        QuoteAssetRegistryV4 next = installTestTarget();
        assertEq(next.quoteLaunch(address(quote)).target, .5 ether);
        (uint256 a,uint256 b) = next.priceUsd(address(quote));
        (uint256 x,uint256 y) = registry.priceUsd(address(quote)); assertEq(a,x); assertEq(b,y);
        assertEq(next.assetCount(), registry.assetCount()); assertEq(next.assetAt(1), address(quote));
        LaunchFactoryV3.CreateParamsV3 memory p = params(address(quote), false);
        p.minTarget = .5 ether; p.maxTarget = p.minTarget;
        address token = f.createTokenV3(p); (,address pool,,) = f.projects(token);
        quote.mint(address(this), 1 ether); quote.approve(pool, 1 ether);
        StandardCurve c = StandardCurve(pool); c.buy(1 ether,1,block.timestamp,address(this)); c.graduate();
        assertEq(quote.balanceOf(c.pair()), .49 ether);
        assertTrue(IERC20(c.pair()).balanceOf(address(0xdead)) > 0);
    }
    function testForkTestGoalMigratesAndTradesOnRealPancake() public {
        if (vm.envOr("RUN_BSC_FORK", uint256(0)) == 0) { vm.skip(true); return; }
        vm.createSelectFork(vm.envOr("BSC_RPC_URL", string("https://bsc-dataseed.bnbchain.org")));
        vm.deal(address(this), 1 ether);
        LaunchFactoryV6 live = LaunchFactoryV6(payable(0x0abc6174ee9f9600243D14F83E215993b8BbABEb));
        QuoteAssetRegistryV4 next = new QuoteAssetRegistryV4(live.owner(), address(live.quoteRegistry()), .1 ether);
        address tokenDeployer=address(live.standaloneTokenDeployer());
        address curveDeployer=address(live.standaloneCurveDeployer());
        vm.prank(live.owner()); live.configureStandardLaunches(address(next), tokenDeployer, curveDeployer);
        LaunchFactoryV3.CreateParamsV3 memory p;
        p.name="Migration test"; p.symbol="MIG"; p.metadataURI="ipfs://test";
        p.expectedConfig=live.launchConfigHash(address(0)); p.minTarget=.1 ether; p.maxTarget=.1 ether;
        p.tax=LaunchTypes.Tax(0,0,10000,0,0,0,address(this),0);
        (address deployer, bytes32 hash)=live.tokenDeploymentConfig();
        for(uint256 i;;i++) {
            uint256 free; assembly("memory-safe"){free:=mload(0x40)}
            p.salt=bytes32(i);
            address predicted=address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff),deployer,keccak256(abi.encode(address(this),p.salt)),hash)))));
            assembly("memory-safe"){mstore(0x40,free)}
            if(uint160(predicted)&0xffff==0x6666 && predicted.code.length==0) break;
        }
        uint256 gross=(uint256(.1 ether)*10000+9899)/9900;
        LaunchFactoryV3.DeveloperBuy memory b=LaunchFactoryV3.DeveloperBuy(gross,0,1,block.timestamp,true,BNBQuoteAdapter.Route(0,new address[](0),""));
        address token=live.createTokenAndBuyV3{value:gross}(p,b);
        (,address pool,,)=live.projects(token); StandardCurve c=StandardCurve(pool);
        assertEq(c.progressBps(),10000); assertEq(c.reserveQuote(),.1 ether);
        vm.prank(address(0x999)); c.graduate(); assertTrue(c.graduated());
        address wbnb=0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
        assertEq(IERC20(wbnb).balanceOf(c.pair()),.098 ether);
        assertEq(IERC20(token).balanceOf(c.pair()),200_000_000 ether);
        assertTrue(IERC20(c.pair()).balanceOf(address(0xdead))>0);
        IPancakeMigrationTest pancake=IPancakeMigrationTest(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        address[] memory path=new address[](2); path[0]=wbnb; path[1]=token;
        uint256 beforeTokens=IERC20(token).balanceOf(address(this));
        pancake.swapExactETHForTokensSupportingFeeOnTransferTokens{value:.0001 ether}(1,path,address(this),block.timestamp);
        uint256 received=IERC20(token).balanceOf(address(this))-beforeTokens; assertTrue(received>0);
        IERC20(token).approve(address(pancake),received); path[0]=token; path[1]=wbnb;
        uint256 beforeBNB=address(this).balance;
        pancake.swapExactTokensForETHSupportingFeeOnTransferTokens(received,1,path,address(this),block.timestamp);
        assertTrue(address(this).balance>beforeBNB);
    }
}
