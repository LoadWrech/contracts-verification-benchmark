// SPDX-License-Identifier: GPL-3.0-only

// A `reveal` or `timeout` transaction won't revert only if contract is in a committed state

rule reveal_timeout_after_isCommitted {
    env e;
    calldataarg args;
    method f;

    f(e, args);

    assert (
        f.selector == sig:reveal(string).selector ||
        f.selector == sig:timeout().selector
    ) => currentContract.isCommitted;

}
