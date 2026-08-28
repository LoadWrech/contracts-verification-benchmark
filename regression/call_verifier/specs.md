The contract has only the function `f` that performs an external call:
```
function f(address a) public {
    (bool s, bytes memory data) = a.call("");
}
```