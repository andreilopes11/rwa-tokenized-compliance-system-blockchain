// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {BaseComplianceModule} from "./BaseComplianceModule.sol";

/// @notice Per-asset suitability gating. Each investor is assigned a suitability tier by
///         the compliance principal; recipients must meet the asset's required tier.
contract SuitabilityTierModule is BaseComplianceModule {
    uint8 public requiredTier;
    mapping(address investor => uint8 tier) public investorTier;

    event RequiredTierSet(uint8 tier);
    event InvestorTierSet(address indexed investor, uint8 tier);

    constructor(address compliance_, address owner_, uint8 requiredTier_)
        BaseComplianceModule(compliance_, owner_)
    {
        requiredTier = requiredTier_;
    }

    function setRequiredTier(uint8 tier) external onlyOwner {
        requiredTier = tier;
        emit RequiredTierSet(tier);
    }

    function setInvestorTier(address investor, uint8 tier) external onlyOwner {
        investorTier[investor] = tier;
        emit InvestorTierSet(investor, tier);
    }

    function moduleCheck(address, address to, uint256, address querying)
        external
        view
        returns (bool)
    {
        if (!_boundCompliance(querying)) return false;
        if (to == address(0)) return true;
        return investorTier[to] >= requiredTier;
    }

    function name() external pure returns (string memory) {
        return "SuitabilityTierModule";
    }
}
