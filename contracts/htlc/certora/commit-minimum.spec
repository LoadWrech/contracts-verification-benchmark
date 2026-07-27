// SPDX-License-Identifier: GPL-3.0-only

// If a `commit` transaction does not revert, then the contract balance should increase by at least `fee` ETH

rule commit_minimum {
    env e;
    bytes32 b;

    commit(e, b);
    
    assert e.msg.value >= currentContract.fee;
}