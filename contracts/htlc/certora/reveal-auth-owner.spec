// SPDX-License-Identifier: GPL-3.0-only

// If a `reveal` transaction does not revert, then the transaction's sender must be the contract's owner

rule reveal_auth_owner {
    env e;
    string s;
    reveal(e, s);

    assert e.msg.sender == currentContract.owner;
}
