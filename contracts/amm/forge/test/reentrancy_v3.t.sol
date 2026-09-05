// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.18;

import "forge-std/Test.sol";
import "versions/AMM_v3.sol";

contract NormalToken is IERC20 {
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowance;

    function totalSupply() external pure returns (uint256) { return 1000000; }

    function mint(address to, uint amount) public {
        balances[to] += amount;
    }

    function balanceOf(address account) external view returns (uint) {
        return balances[account];
    }

    function approve(address spender, uint amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint amount) external returns (bool) {
        require(balances[from] >= amount, "Insufficient balance");
        balances[from] -= amount;
        balances[to] += amount;
        return true;
    }

    function transfer(address to, uint amount) external returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }
}

contract MaliciousToken is IERC20 {
    mapping(address => uint) public balances;
    mapping(address => mapping(address => uint)) public allowance;

    function totalSupply() external pure returns (uint256) { return 1000000; }

    AMM public targetAMM;
    bool public isMalicious;
    uint public targetSharesToBurn;

    function setTarget(AMM _amm) public {
        targetAMM = _amm;
    }

    function mint(address to, uint amount) public {
        balances[to] += amount;
    }

    function balanceOf(address account) external view returns (uint) {
        return balances[account];
    }

    function approve(address spender, uint amount) external returns (bool) {
        allowance[msg.sender][spender] = amount;
        return true;
    }

    function transferFrom(address from, address to, uint amount) external returns (bool) {
        balances[from] -= amount;
        balances[to] += amount;

        if (isMalicious) {

            isMalicious = false;

            if (targetSharesToBurn > 0) {
                targetAMM.redeem(targetSharesToBurn);
            }
        }
        return true;
    }

    function transfer(address to, uint amount) external returns (bool) {
        balances[msg.sender] -= amount;
        balances[to] += amount;
        return true;
    }

    function armAttack() public {
        isMalicious = true;
        targetSharesToBurn = targetAMM.minted(address(this));
    }

    function approveT1(IERC20 _t1) public {
        _t1.approve(address(targetAMM), type(uint).max);
        allowance[address(this)][address(targetAMM)] = type(uint).max;
    }

    function executeDeposit(uint amount0, uint amount1) public {
        targetAMM.deposit(amount0, amount1);
    }
}

contract ReentrancyV3Test is Test {
    AMM public amm;
    MaliciousToken public t0;
    NormalToken public t1;

    address public attacker = address(0x1337);

    function setUp() public {
        t0 = new MaliciousToken();
        t1 = new NormalToken();

        amm = new AMM(IERC20(address(t0)), IERC20(address(t1)));
        t0.setTarget(amm);

        t0.mint(address(this), 135000);
        t1.mint(address(this), 1000);
        t0.approve(address(amm), type(uint).max);
        t1.approve(address(amm), type(uint).max);

        amm.deposit(135000, 1000);
    }

    function test_reentrancy_deposit_precision() public {

        t0.mint(address(t0), 135 * 2);
        t1.mint(address(t0), 1 * 2);
        t0.approveT1(t1);

        t0.executeDeposit(135, 1);

        uint supplyMid = amm.supply();
        console.log("Supply before attack:", supplyMid);
        console.log("MaliciousToken shares ready:", amm.minted(address(t0)));

        t0.armAttack();

        vm.expectRevert();
        t0.executeDeposit(135, 1);
    }
}
