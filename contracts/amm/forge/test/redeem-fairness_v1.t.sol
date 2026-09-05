// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "versions/AMM_v1.sol" as V1;
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

contract RedeemFairnessV1Test is Test {
    V1.AMM ammV1;
    MockToken token0;
    MockToken token1;
    address lp = address(0x1337);

    function setUp() public {
        token0 = new MockToken();
        token1 = new MockToken();
        ammV1 = new V1.AMM(IERC20(address(token0)), IERC20(address(token1)));
        token0.transfer(lp, 100_000);
        token1.transfer(lp, 100_000);
    }

    // redeem-fairness:
    // After a non-reverting `redeem(liquidity_tokens)` transaction, the real token balances of the sender strictly increase by an amount perfectly proportional to the burned liquidity tokens relative to the contract's total real balances.

    // PoC:
    // - Step 1 (setup): The user initializes the pool. A massive donation is sent directly to the contract.
    // - Step 2 (transaction): The user redeems their shares. In V4, the contract calculates the payout using stale internal reserves, depriving the user of the donated value. In V1, it uses real balances, distributing the value fairly.
    function test_redeem_fairness_v1() public {
        vm.startPrank(lp);
        token0.approve(address(ammV1), 10_000);
        token1.approve(address(ammV1), 10_000);
        ammV1.deposit(10_000, 10_000);
        vm.stopPrank();

        token0.transfer(address(ammV1), 5_000);

        vm.startPrank(lp);
        uint b0_before = token0.balanceOf(lp);
        ammV1.redeem(ammV1.minted(lp));
        uint b0_after = token0.balanceOf(lp);
        vm.stopPrank();

        uint expected = (9000 * 15000) / 10000;
        assertEq(b0_after - b0_before, expected);
    }
}
