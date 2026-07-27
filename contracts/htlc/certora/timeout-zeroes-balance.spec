// SPDX-License-Identifier: GPL-3.0-only

// If a `timeout` transaction does not revert, it must completely drain the contract's balance

rule timeout_zeroes_balance {
    env e;
    
    address verifier = currentContract.verifier;
    require currentContract != verifier;
    timeout(e);

    assert nativeBalances[currentContract] == 0;
}