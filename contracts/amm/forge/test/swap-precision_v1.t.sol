// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "versions/AMM_v1.sol" as V1;
import "versions/lib/ERC20.sol";

contract SwapPrecisionV1Test is Test {
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

    // swap-precision:
    // After a non-reverting `swap(token, amountIn, 0)` transaction where `amountIn` is strictly positive, the contract's balance of the output token is strictly decreased by a positive amount.

    // PoC:
    // - Step 1 (setup): The user deposits massive liquidity, creating a large denominator.
    // - Step 2 (attack): The attacker swaps a microscopic amount (1 wei). Due to integer division truncation, the output evaluates to 0, absorbing the input without returning any value.
    function test_swap_precision_zero_return_v1() public {
        vm.startPrank(user);
        t0.approve(address(ammV1), 10000);
        t1.approve(address(ammV1), 10000);
        ammV1.deposit(10000, 10000);
        vm.stopPrank();

        vm.startPrank(attacker);
        t0.approve(address(ammV1), 1);
        
        uint bal1Before = t1.balanceOf(attacker);
        
        // Attacker swaps 1 wei of token 0 for token 1
        ammV1.swap(address(t0), 1, 0);
        
        uint bal1After = t1.balanceOf(attacker);
        
        assertEq(bal1After - bal1Before, 0, "V1 truncates the output of a 1 wei swap to 0, absorbing the input.");
        vm.stopPrank();
    }
}
