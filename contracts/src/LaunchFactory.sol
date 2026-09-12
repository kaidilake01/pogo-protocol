// SPDX-License-Identifier: MIT
pragma solidity 0.8.28;
import {LaunchFactoryV7} from "../internal/LaunchFactoryV7.sol";
import {StandaloneCurveDeployer} from "../internal/StandaloneCurveDeployer.sol";
import {StandaloneVaultDeployer} from "../internal/StandaloneVaultDeployer.sol";

/// @notice Append-only template registration; each project deploys standalone contracts.
contract LaunchFactoryV8 is LaunchFactoryV7 {
    struct Template { address curveDeployer; address vaultDeployer; uint8 kind; bool enabled; }
    mapping(uint256=>Template) public launchTemplates;
    mapping(address=>uint256) public projectTemplate;
    uint256 private activeTemplate;
    uint256[] public launchTemplateIds;
    uint256 public constant LAUNCH_TEMPLATES_VERSION=1;
    event LaunchTemplateRegistered(uint256 indexed id,address curveDeployer,address vaultDeployer,uint8 kind);
    event LaunchTemplateEnabled(uint256 indexed id,bool enabled);
    event ProjectTemplateSelected(address indexed token,uint256 indexed templateId);

    function registerLaunchTemplate(uint256 id,address curve_,address vault_,uint8 kind_) public onlyOwner {
        if(id==0||id>255||launchTemplates[id].curveDeployer!=address(0)||curve_.code.length==0||vault_.code.length==0
            ||StandaloneCurveDeployer(curve_).factory()!=address(this)||StandaloneCurveDeployer(curve_).KIND()!=2
            ||StandaloneVaultDeployer(vault_).factory()!=address(this)||StandaloneVaultDeployer(vault_).KIND()!=3)revert InvalidConfig();
        launchTemplates[id]=Template(curve_,vault_,kind_,true);
        launchTemplateIds.push(id);
        emit LaunchTemplateRegistered(id,curve_,vault_,kind_);
    }
    function launchTemplateCount() external view returns(uint256) { return launchTemplateIds.length; }
    function configureLaunchTemplates(address fair_,address mining_,address vault_) external onlyOwner {
        registerLaunchTemplate(1,fair_,vault_,0);
        registerLaunchTemplate(2,mining_,vault_,1);
    }
    function setLaunchTemplateEnabled(uint256 id,bool enabled) external onlyOwner {
        if(launchTemplates[id].curveDeployer==address(0))revert InvalidConfig();
        launchTemplates[id].enabled=enabled;emit LaunchTemplateEnabled(id,enabled);
    }
    function templateConfigHash(address quote,uint256 id) public view returns(bytes32) {
        Template memory t=launchTemplates[id];
        if(!t.enabled)revert InvalidConfig();
        return keccak256(abi.encode(super.launchConfigHash(quote),id,t.curveDeployer,t.vaultDeployer,t.kind,t.enabled));
    }
    function launchConfigHash(address quote) public view override returns(bytes32) {
        return activeTemplate==0?super.launchConfigHash(quote):templateConfigHash(quote,activeTemplate);
    }
    function createTokenWithTemplateV8(CreateParamsV3 calldata p,uint256 id) external payable returns(address token) {
        _select(id);token=super.createTokenV3(p);_finish(token,id);
    }
    function createTokenAndBuyWithTemplateV8(CreateParamsV3 calldata p,DeveloperBuy calldata b,uint256 id) external payable returns(address token) {
        _select(id);token=super.createTokenAndBuyV3(p,b);_finish(token,id);
    }
    function _select(uint256 id) private {
        if(activeTemplate!=0||!launchTemplates[id].enabled)revert InvalidConfig();
        activeTemplate=id;
    }
    function _finish(address token,uint256 id) private {
        activeTemplate=0;projectTemplate[token]=id;emit ProjectTemplateSelected(token,id);
    }
    function _deployPoolV3() internal override returns(address) {
        return activeTemplate==0?super._deployPoolV3():StandaloneCurveDeployer(launchTemplates[activeTemplate].curveDeployer).deploy();
    }
    function _deployVaultV3() internal override returns(address) {
        return activeTemplate==0?super._deployVaultV3():StandaloneVaultDeployer(launchTemplates[activeTemplate].vaultDeployer).deploy();
    }
}
