// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "forge-std/Test.sol";
import "../src/facets/utilityFacets/dca/DCAFacet.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockERC20 is ERC20 {
    constructor(string memory name, string memory symbol) ERC20(name, symbol) {
        _mint(msg.sender, 1e24);
    }
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}

contract MockRouter {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint,
        address[] calldata path,
        address to,
        uint
    ) external {
        // naive: transfer amountIn of path[0] from caller (which must have approved router) to `to` as path[1]
        // For test, assume caller is the facet which approved; perform simple transfer from facet to `to`
        IERC20(path[0]).transferFrom(msg.sender, to, amountIn);
    }
}

contract DCAFacetTest is Test {
    DCAFacet dca;
    MockERC20 tokenA;
    MockERC20 tokenB;
    MockRouter router;

    function setUp() public {
        tokenA = new MockERC20("A", "A");
        tokenB = new MockERC20("B", "B");
        router = new MockRouter();
        dca = new DCAFacet();

        // set router via owner call; in this simple test we don't use FacetBase
    }
}
