// SPDX-License-Identifier: GPL-3.0-only

// After a `commit` transaction that does not revert, the contract's balance must be equal to the transaction's value

rule contract_balance_is_commit_value {
    env e;
    bytes32 h;
    require currentContract != currentContract.owner;
    require currentContract.owner != currentContract.verifier;
    require e.msg.sender != currentContract;
    commit(e, h);
    assert nativeBalances[currentContract] == e.msg.value;
}
