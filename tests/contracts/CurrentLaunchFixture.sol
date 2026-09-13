// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {TestBase} from "./TestBase.sol";
import {QuoteMock,PriceMock} from "./QuoteMocks.sol";
import {MockPair,MockRouter,MockWBNB} from "./Mocks.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {LaunchFactory} from "../../contracts/internal/LaunchFactory.sol";
import {LaunchFactoryV3} from "../../contracts/internal/LaunchFactoryV3.sol";
import {LaunchFactoryV4} from "../../contracts/internal/LaunchFactoryV4.sol";
import {LaunchFactoryV5} from "../../contracts/internal/LaunchFactoryV5.sol";
import {LaunchToken} from "../../contracts/internal/LaunchToken.sol";
import {DividendVault} from "../../contracts/internal/DividendVault.sol";
import {BondingCurve} from "../../contracts/internal/BondingCurve.sol";
import {QuoteAssetRegistry} from "../../contracts/internal/QuoteAssetRegistry.sol";
import {QuoteAssetRegistryV3} from "../../contracts/internal/QuoteAssetRegistryV3.sol";
import {LaunchTypes} from "../../contracts/internal/LaunchTypes.sol";
import {LaunchTokenV3} from "../../contracts/internal/LaunchTokenV3.sol";
import {MultiAssetCurve} from "../../contracts/internal/MultiAssetCurve.sol";
import {RevenueVault} from "../../contracts/internal/RevenueVault.sol";
import {BNBQuoteAdapter} from "../../contracts/src/BNBQuoteAdapter.sol";
import {StandaloneVaultDeployer} from "../../contracts/internal/StandaloneVaultDeployer.sol";
import {StandardLaunchToken} from "../../contracts/src/LaunchToken.sol";
import {StandardTokenDeployer} from "../../contracts/src/TokenDeployer.sol";
import {ReflowCurveDeployer} from "../../contracts/src/MiningCurveDeployer.sol";
import {FixedAllocationMiningDeployer} from "../../contracts/src/Mining.sol";
import {QuoteVaultDeployer} from "../../contracts/src/RevenueVault.sol";
import {DirectedLaunchCurveDeployer} from "../../contracts/src/TransferCurveDeployer.sol";
import {QuoteAssetRegistryV7} from "../../contracts/src/QuoteAssetRegistry.sol";
import {LaunchFactoryV8} from "../../contracts/src/LaunchFactory.sol";

contract PredictablePair is MockPair {
    constructor() MockPair(PredictableFactory(msg.sender).a(),PredictableFactory(msg.sender).b()) {}
}
contract PredictableFactory {
    address public a;address public b;
    mapping(address=>mapping(address=>address)) public getPair;
    function INIT_CODE_PAIR_HASH() external pure returns(bytes32){return keccak256(type(PredictablePair).creationCode);}
    function createPair(address a_,address b_) external returns(address p){
        require(a_!=b_&&getPair[a_][b_]==address(0));
        (a,b)=a_<b_?(a_,b_):(b_,a_);
        p=address(new PredictablePair{salt:keccak256(abi.encodePacked(a,b))}());
        getPair[a_][b_]=p;getPair[b_][a_]=p;
    }
}

abstract contract CurrentLaunchFixture is TestBase {
    LaunchFactoryV8 f;QuoteAssetRegistryV3 registry;QuoteMock quote;
    MockWBNB wrapped;MockRouter router;PredictableFactory dex;
    address constant CREATOR=address(0x123);address constant TREASURY=address(0x777);
    function setUp() public {
        vm.deal(address(this),200 ether);vm.warp(1_000_000);
        wrapped=new MockWBNB();dex=new PredictableFactory();router=new MockRouter(address(wrapped),address(dex));
        LaunchFactoryV8 implementation=new LaunchFactoryV8();
        f=LaunchFactoryV8(payable(address(new ERC1967Proxy(address(implementation),abi.encodeCall(implementation.initialize,
            (address(this),TREASURY,address(router),address(new LaunchToken()),address(new DividendVault()),address(new BondingCurve())))))));
        registry=new QuoteAssetRegistryV3(address(this));quote=new QuoteMock(18);
        PriceMock bnb=new PriceMock();PriceMock stock=new PriceMock();stock.set(140e8,block.timestamp);
        registry.configure(address(0),QuoteAssetRegistry.Asset(address(bnb),0,3600,18,8,0,true));
        registry.configure(address(quote),QuoteAssetRegistry.Asset(address(stock),0,3600,18,8,0,true));
        f.setTemplatesV3(address(registry),address(new LaunchTokenV3()),address(new RevenueVault()),address(new MultiAssetCurve()));
        f.setBNBAdapter(address(new BNBQuoteAdapter(address(wrapped),address(router),address(router))));
        ReflowCurveDeployer curve=new ReflowCurveDeployer(address(f),address(new FixedAllocationMiningDeployer()));
        QuoteVaultDeployer vault=new QuoteVaultDeployer(address(f));
        f.setStandaloneDeployers(address(new StandardTokenDeployer(address(f))),address(curve),address(vault));
        f.configureMiningLaunches(address(new QuoteAssetRegistryV7(address(registry),6.666 ether)),address(curve),address(vault));
        f.registerLaunchTemplate(12,address(curve),address(vault),1);
        f.registerLaunchTemplate(10,address(new DirectedLaunchCurveDeployer(address(f))),address(vault),0);
    }
    function params(address asset,bool taxed) internal view returns(LaunchFactoryV3.CreateParamsV3 memory p){
        p.name="Standard";p.symbol="STD";p.metadataURI="ipfs://test";p.quoteAsset=asset;
        p.expectedConfig=f.launchConfigHash(asset);p.minTarget=QuoteAssetRegistry(address(f.quoteRegistry())).quoteLaunch(asset).target;p.maxTarget=p.minTarget;
        p.tax=taxed?LaunchTypes.Tax(300,300,4000,2000,3000,1000,CREATOR,0):LaunchTypes.Tax(0,0,10000,0,0,0,CREATOR,0);
        (address deployer,bytes32 hash)=f.tokenDeploymentConfig();
        for(uint256 i;;i++){
            uint256 free;assembly("memory-safe"){free:=mload(0x40)}
            p.salt=bytes32(i);address predicted=address(uint160(uint256(keccak256(abi.encodePacked(bytes1(0xff),deployer,keccak256(abi.encode(address(this),p.salt)),hash)))));
            assembly("memory-safe"){mstore(0x40,free)}
            if(uint160(predicted)&0xffff==0x6666&&predicted.code.length==0)break;
        }
    }
}
