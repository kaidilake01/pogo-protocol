// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {AutomaticRevenueTest} from "./AutomaticRevenue.t.sol";
import {LaunchFactory} from "../../contracts/src/LaunchFactory.sol";
import {LaunchFactoryV3} from "../../contracts/src/LaunchFactoryV3.sol";
import {LaunchFactoryV4} from "../../contracts/src/LaunchFactoryV4.sol";
import {LaunchTypes} from "../../contracts/src/v3/LaunchTypes.sol";
import {StandaloneToken} from "../../contracts/src/v4/StandaloneToken.sol";
import {LaunchTokenV3} from "../../contracts/src/v3/LaunchTokenV3.sol";
import {StandaloneTokenDeployer} from "../../contracts/src/v4/StandaloneTokenDeployer.sol";
import {StandaloneCurveDeployer} from "../../contracts/src/v4/StandaloneCurveDeployer.sol";
import {StandaloneVaultDeployer} from "../../contracts/src/v4/StandaloneVaultDeployer.sol";

// Re-run complete creation, buy/sell, tax, graduation and automation scenarios with full runtimes.
contract StandaloneLaunchTest is AutomaticRevenueTest {
    function setUp() public override {
        super.setUp();
        address token=address(new StandaloneTokenDeployer(address(f)));
        address curve=address(new StandaloneCurveDeployer(address(f)));
        address vault=address(new StandaloneVaultDeployer(address(f)));
        f.upgradeToAndCall(address(new LaunchFactoryV4()),abi.encodeCall(LaunchFactoryV4.setStandaloneDeployers,(token,curve,vault)));
    }
    function _params(address asset,address recipient) internal view override returns(LaunchFactoryV3.CreateParamsV3 memory p){
        p.name="Standalone Launch";p.symbol="FULL";p.metadataURI="ipfs://test";p.quoteAsset=asset;
        p.expectedConfig=f.launchConfigHash(asset);p.minTarget=registry.quoteLaunch(asset).target;p.maxTarget=p.minTarget;
        p.tax=LaunchTypes.Tax(200,500,4000,2000,3000,1000,recipient,0);
        (address deployer,bytes32 hash)=LaunchFactoryV4(payable(address(f))).tokenDeploymentConfig();
        for(uint256 i;;i++){
            p.salt=bytes32(i);uint256 free;assembly("memory-safe"){free:=mload(0x40)}
            address predicted=address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff),deployer,keccak256(abi.encode(address(this),p.salt)),hash)))));
            assembly("memory-safe"){mstore(0x40,free)}
            if(uint160(predicted)&0xffff==0x6666&&predicted.code.length==0)break;
        }
    }
    function testFullRuntimesAndImmediateIrrevocableRenouncement() public {
        LaunchFactoryV3.CreateParamsV3 memory p=_params(address(0),RECIPIENT);
        address predicted=f.predictTokenV3(address(this),p.salt);
        StandaloneToken token=StandaloneToken(f.createTokenV3{value:.01 ether}(p));
        (,address pool,address vault,)=f.projects(address(token));
        assertEq(address(token),predicted);assertTrue(address(token).code.length>1000);assertTrue(pool.code.length>1000);assertTrue(vault.code.length>1000);
        assertEq(token.owner(),address(0));assertEq(token.totalSupply(),1_000_000_000 ether);
        vm.expectRevert();token.transferOwnership(address(this));
        vm.expectRevert();token.renounceOwnership();
        vm.expectRevert();token.initialize(LaunchTokenV3.Init("X","X","",pool,vault,0,0));
        bytes32 codeHash=address(token).codehash;
        f.upgradeToAndCall(address(new LaunchFactoryV4()),"");
        assertTrue(address(token).codehash==codeHash);assertEq(token.owner(),address(0));assertEq(token.buyTaxBps(),200);
    }
    function testLegacyProxyLaunchEntryDisabled() public {
        LaunchFactory.CreateParams memory p;
        vm.expectRevert(LaunchFactoryV4.LegacyCreationDisabled.selector);f.createToken{value:.01 ether}(p);
    }
    function testOnlyFactoryCanDeployStandaloneContracts() public {
        LaunchFactoryV4 factory4=LaunchFactoryV4(payable(address(f)));
        StandaloneTokenDeployer token=factory4.standaloneTokenDeployer();StandaloneCurveDeployer curve=factory4.standaloneCurveDeployer();StandaloneVaultDeployer vault=factory4.standaloneVaultDeployer();
        vm.expectRevert();token.deploy(bytes32(uint256(1)));
        vm.expectRevert();curve.deploy();
        vm.expectRevert();vault.deploy();
    }
    function testV2MethodsAndOwnershipPreservedAfterUpgrade() public override {
        assertEq(f.owner(),address(this));assertEq(f.treasury(),TREASURY);assertEq(f.PROTOCOL_VERSION(),2);
        assertTrue(f.tokenImplementation().code.length>0);assertTrue(f.poolImplementation().code.length>0);assertTrue(f.vaultImplementation().code.length>0);
        LaunchFactory.CreateParams memory p;
        vm.expectRevert(LaunchFactoryV4.LegacyCreationDisabled.selector);f.createToken{value:.01 ether}(p);
    }
}
