// SPDX-License-Identifier: GPL-3.0-only

// No succesful transaction can change the address of the verifier

rule verifier_immutable(method f) {
    address _pre_verifier = currentContract.verifier;
    env e;
    calldataarg args;
    f(e, args);
    assert currentContract.verifier == _pre_verifier,
        "verifier changed after calling function";
}