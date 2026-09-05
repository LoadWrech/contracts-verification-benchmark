// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "versions/AMM_v2.sol" as V2;
import "versions/lib/IERC20.sol";

contract MockToken is IERC20 {
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply = 1000000 * 1e18;
    constructor() { balanceOf[msg.sender] = totalSupply; }
    function transfer(address to, uint256 value) external returns (bool) {
        balanceOf[msg.sender] -= value; balanceOf[to] += value; return true;
    }
    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value; return true;
    }
    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        allowance[from][msg.sender] -= value; balanceOf[from] -= value; balanceOf[to] += value; return true;
    }
}

contract PriceEqualityV2Test is Test {
    V2.AMM ammV2;
    MockToken token0;
    MockToken token1;

    function setUp() public {
        token0 = new MockToken();
        token1 = new MockToken();
        ammV2 = new V2.AMM(IERC20(address(token0)), IERC20(address(token1)));
        token0.approve(address(ammV2), 10_000);
        token1.approve(address(ammV2), 10_000);
    }

    // price-equality:
    // If the tracked reserves of the contract are equal and strictly positive, the `price(token)` function returns identical values for both token0 and token1.

    // PoC:
    // - Step 1 (setup): The user deposits equal amounts of token0 and token1.
    // - Step 2 (transaction): The price is queried. Without the 1e18 scaling factor, integer division truncates the result, returning 1 instead of the expected 1e18 precision baseline.
    function test_price_equality_v2() public {
        ammV2.deposit(10_000, 10_000);
        uint price = ammV2.price(address(token0));
        assertEq(price, 1e18, "Price should be exactly 1e18 in v2");
    }
}
