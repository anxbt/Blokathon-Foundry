// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "./DCAFacetStorage.sol";
import "../../Facet.sol";

contract DCAFacetBase is Facet {
    using DCAFacetStorage for DCAFacetStorage.Layout;

    function _onlyPlanOwner(uint256 planId) internal view returns (DCAFacetStorage.Plan storage p) {
        DCAFacetStorage.Layout storage s = DCAFacetStorage.layout();
        p = s.plans[planId];
        require(p.user == msg.sender, "DCA: not owner");
    }
}