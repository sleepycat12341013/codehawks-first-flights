# CodeHawks First Flights — Security Review Portfolio

A collection of my smart contract security reviews submitted to [CodeHawks First Flights](https://www.codehawks.com/first-flights).
Each entry contains the findings I reported, with proof-of-concept (PoC) tests written in Foundry.

> All reports are published **after** the corresponding First Flight has ended, in accordance with the competition rules.

---

## Reviews

| First Flight | Type | Findings | Report |
|--------------|------|----------|--------|
| [2023-10 PasswordStore](./2023-10-PasswordStore/) | Access control / On-chain privacy | 🔴 2 High | [EN](./2023-10-PasswordStore/findings-report.md) · [JP](./2023-10-PasswordStore/findings-report-jp.md) · [PoC](./2023-10-PasswordStore/PasswordStore.t.poc.sol) |

<!-- Add new First Flights as new rows above. -->

---

## Severity Legend

| Badge | Severity |
|-------|----------|
| 🔴 | High |
| 🟠 | Medium |
| 🟡 | Low |
| 🔵 | Informational / Gas |

## Methodology

- **Manual review** of the contract source against its stated intent (NatSpec / spec).
- **Proof-of-Concept tests** in [Foundry](https://book.getfoundry.sh/) — every finding is backed by a test that passes, demonstrating the vulnerability is exploitable.
- Each report follows a standard structure: *Severity · Location · Description · Impact · Proof of Concept · Recommended Mitigation*.

## About

These reviews are produced for educational and portfolio purposes to demonstrate my smart contract security skills and experience.

- GitHub: [@sleepycat12341013](https://github.com/sleepycat12341013)
