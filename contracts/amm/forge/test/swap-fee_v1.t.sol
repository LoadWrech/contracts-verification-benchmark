// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "versions/AMM_v1.sol" as V1;
import "versions/lib/ERC20.sol";

contract SwapFeeV1Test is Test {
    V1.AMM public ammV1;
    ERC20 public t0;
    ERC20 public t1;
    address user = address(0x1234);
    address attacker = address(0x5678);

    function setUp() public {
        t0 = new ERC20(1_000_000);
        t1 = new ERC20(1_000_000);
        ammV1 = new V1.AMM(t0, t1);

        t0.transfer(user, 100000);
        t1.transfer(user, 100000);
        t0.transfer(attacker, 20000);
    }

    // swap-fee:
    // After a non-reverting `swap(token, x_in, x_out_min)` transaction, the mathematical product of the contract's tracked reserves strictly increases.

    // PoC:
    // - Step 1 (setup): The user deposits initial liquidity.
    // - Step 2 (transaction): The attacker performs a swap. Because no swap fee is applied in V3/V4, the constant product remains exactly the same instead of strictly increasing to reward liquidity providers.
    function test_swap_fee_presence_v1() public {
        vm.startPrank(user);
        t0.approve(address(ammV1), 10000);
        t1.approve(address(ammV1), 10000);
        ammV1.deposit(10000, 10000);
        vm.stopPrank();

        uint k_before = ammV1.r0() * ammV1.r1();

        vm.startPrank(attacker);
        t0.approve(address(ammV1), 10000);
        ammV1.swap(address(t0), 10000, 0);
        vm.stopPrank();

        uint k_after = ammV1.r0() * ammV1.r1();
        assertGt(k_after, k_before, "V1 should strictly increase K (satisfies property)");
    }
}
