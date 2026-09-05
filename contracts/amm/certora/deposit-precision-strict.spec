/// @custom:property deposit-precision-strict
/// @custom:description After a non-reverting `deposit` transaction where the deposited amounts are proportional to the reserves and are at least one-thousandth of the current reserves, the minted liquidity tokens are strictly positive and equal to the proportion between the deposited amounts and the contract's existing reserves.

rule deposit_precision_strict(uint amount0, uint amount1) {
    
    env e;
    uint _supply = currentContract.supply(e);

    // Inflation attack
    require(_supply == 0 || _supply >= 1000);

    require(currentContract.t0(e) != currentContract.t1(e));
    require(e.msg.sender != currentContract);

    uint _r0 = currentContract.r0(e);
    uint _r1 = currentContract.r1(e);

    require(_r0 >= 1000);
    require(_r1 >= 1000);

    require(amount0 * 1000 >= _r0);
    require(amount1 * 1000 >= _r1);

    require(amount0 * _r1 == amount1 * _r0);

    mathint expectedMint = (amount0 * _supply) / _r0;
    assert(_supply > 0 => expectedMint > 0);

    deposit(e, amount0, amount1);

    uint newSupply = currentContract.supply(e);
    mathint minted = newSupply - _supply;

    assert(_supply > 0 => minted > 0);
    // minted : _supply = amount0 : _r0
    assert(_supply > 0 => (minted * _r0 == amount0 * _supply));
}
