# Call Verifier

## Specification
The contract has only the function `f` that performs an external call:
```
function f(address a) public {
    (bool s, bytes memory data) = a.call("");
}
```

## Properties
- **call-failure**: the external call fails
- **call-success**: the external call succeeds
- **ex-call-is-made**: an external call has been performed

## Verification data

- [Ground truth](ground-truth.csv)
- [Solcmc/z3](solcmc-z3.csv)
- [Solcmc/Eldarica](solcmc-eld.csv)
- [Certora](certora.csv)
- [Halmos](halmos.csv)