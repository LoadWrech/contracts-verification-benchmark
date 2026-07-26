// SPDX-License-Identifier: GPL-3.0-only

// If contract is in a committed state, no transaction should be able to reverse it back to an uncommited state

rule cant_uncommit {
    env e;
    require currentContract.isCommitted;

    method f;
    calldataarg args;

    f(e, args);

    assert currentContract.isCommitted;
}
