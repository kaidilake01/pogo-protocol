// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {MiningGraduationTest} from "./MiningGraduation.t.sol";
import {LaunchFactoryV8} from "../../contracts/src/LaunchFactory.sol";
import {LaunchFactoryV3} from "../../contracts/internal/LaunchFactoryV3.sol";
import {FairLaunchCurve} from "../../contracts/internal/FairLaunchCurve.sol";
import {FairLaunchCurveDeployer} from "../../contracts/internal/FairLaunchCurveDeployer.sol";
import {MiningCurve} from "../../contracts/internal/MiningCurve.sol";
import {LaunchMining} from "../../contracts/internal/LaunchMining.sol";
import {StandardLaunchToken} from "../../contracts/src/LaunchToken.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LaunchTemplatesTest is MiningGraduationTest {
    function templates() internal returns(LaunchFactoryV8 next) {
        install();
        FairLaunchCurveDeployer fair=new FairLaunchCurveDeployer(address(f));
        f.upgradeToAndCall(address(new LaunchFactoryV8()),abi.encodeCall(LaunchFactoryV8.configureLaunchTemplates,(address(fair),address(f.standaloneCurveDeployer()),address(f.standaloneVaultDeployer()))));
        next=LaunchFactoryV8(payable(address(f)));
    }
    function templateParams(LaunchFactoryV8 next,uint256 id) internal view returns(LaunchFactoryV3.CreateParamsV3 memory p) {
        p=params(address(0),false);p.minTarget=6.666 ether;p.maxTarget=p.minTarget;p.expectedConfig=next.templateConfigHash(address(0),id);
    }
    function testTemplatesNormalBurnsRemainderAndMiningFundsIt() public {
        LaunchFactoryV8 next=templates();
        StandardLaunchToken a=StandardLaunchToken(next.createTokenWithTemplateV8(templateParams(next,1),1));
        (,address pa,,)=f.projects(address(a));FairLaunchCurve ca=FairLaunchCurve(pa);
        StandardLaunchToken b=StandardLaunchToken(next.createTokenWithTemplateV8(templateParams(next,2),2));
        (,address pb,,)=f.projects(address(b));MiningCurve cb=MiningCurve(pb);
        assertEq(ca.spotPrice(),cb.spotPrice());assertEq(ca.graduationTarget(),cb.graduationTarget());
        assertEq(ca.stakingPool(),address(0));assertTrue(cb.stakingPool()!=address(0));
        ca.buy{value:10 ether}(10 ether,1,block.timestamp,address(this));cb.buy{value:10 ether}(10 ether,1,block.timestamp,address(this));
        assertEq(a.balanceOf(address(this)),b.balanceOf(address(this)));uint256 price=ca.spotPrice();
        ca.graduate();cb.graduate();
        assertEq(a.balanceOf(pa),0);assertEq(a.totalSupply(),a.balanceOf(address(this))+a.balanceOf(ca.pair()));
        assertEq(b.totalSupply()-a.totalSupply(),LaunchMining(cb.stakingPool()).rewardBudget());
        assertEq(a.balanceOf(ca.pair()),b.balanceOf(cb.pair()));assertEq(price,cb.spotPrice());
        assertTrue(IERC20(ca.pair()).balanceOf(address(0xdead))>0);
        assertEq(next.projectTemplate(address(a)),1);assertEq(next.projectTemplate(address(b)),2);
    }
    function testTemplatesRejectWrongHashDisabledUnknownAndNonOwner() public {
        LaunchFactoryV8 next=templates();LaunchFactoryV3.CreateParamsV3 memory p=templateParams(next,1);
        vm.expectRevert();next.createTokenWithTemplateV8(p,2);
        vm.expectRevert();next.createTokenWithTemplateV8(p,3);
        vm.prank(address(123));vm.expectRevert();next.setLaunchTemplateEnabled(1,false);
        next.setLaunchTemplateEnabled(1,false);vm.expectRevert();next.createTokenWithTemplateV8(p,1);
        next.setLaunchTemplateEnabled(1,true);address token=next.createTokenWithTemplateV8(p,1);assertEq(next.projectTemplate(token),1);
        address curve=address(f.standaloneCurveDeployer());address vault=address(f.standaloneVaultDeployer());
        vm.expectRevert();next.registerLaunchTemplate(1,curve,vault,0);
    }
    function testTemplateInitialBuyAndLegacyDefaultRemainIndependent() public {
        LaunchFactoryV8 next=templates();
        LaunchFactoryV3.DeveloperBuy memory buy;buy.amount=.01 ether;buy.minTokens=1;buy.deadline=block.timestamp;buy.payWithBNB=true;
        address a=next.createTokenAndBuyWithTemplateV8{value:.01 ether}(templateParams(next,1),buy,1);
        assertTrue(IERC20(a).balanceOf(address(this))>0);assertEq(next.projectTemplate(a),1);
        LaunchFactoryV3.CreateParamsV3 memory p=templateParams(next,2);p.expectedConfig=next.launchConfigHash(address(0));
        address b=next.createTokenV3(p);(,address pool,,)=next.projects(b);
        assertTrue(MiningCurve(pool).stakingPool()!=address(0));assertEq(next.projectTemplate(b),0);
    }
}
