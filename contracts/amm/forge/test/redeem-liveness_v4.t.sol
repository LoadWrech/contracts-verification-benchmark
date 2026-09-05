// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "versions/AMM_v4.sol";
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

contract RedeemLivenessV3Test is Test {
    AMM amm;
    MockToken token0;
    MockToken token1;

    address user = address(0x1234);

    function setUp() public {

        token0 = new MockToken("Token 0", "T0");
        token1 = new MockToken("Token 1", "T1");

        amm = new AMM(IERC20(address(token0)), IERC20(address(token1)));

        token0.transfer(user, 100_000);
        token1.transfer(user, 100_000);
    }

    // redeem-liveness:
    // If the contract's tracked reserves are equal to its real balances, a `redeem(liquidity_tokens)` transaction by a valid sender possessing a strictly positive amount of liquidity tokens never reverts.

    // PoC:
    // - Step 1 (setup): The user initializes the pool and holds 100% of the shares.
    // - Step 2 (transaction): The user attempts to redeem all their shares. The transaction reverts due to a flawed `require(x < supply)` check, creating a mathematical deadlock where the last provider can never exit.
    function test_redeem_liveness_bug() public {
        console.log("--- STARTING REDEEM LIVENESS POC ON AMM_v3 ---");

        vm.startPrank(user);
        token0.approve(address(amm), 10_000);
        token1.approve(address(amm), 10_000);

        amm.deposit(10_000, 10_000);
        console.log("User successfully deposited 10,000 T0 and 10,000 T1.");

        uint aliceShares = amm.minted(user);
        uint totalShares = amm.supply();
        console.log("User's Shares:", aliceShares);
        console.log("Total AMM Supply:", totalShares);

        console.log("\nAttempting to redeem 100% of the pool's liquidity...");

        vm.expectRevert();
        amm.redeem(totalShares);

        console.log("[x] Redeem REVERTED! User's funds are frozen forever.");
        vm.stopPrank();

        console.log("\n--- POC SUCCESSFUL ---");
        console.log("The formal verification finding is practically exploitable!");
    }
}
