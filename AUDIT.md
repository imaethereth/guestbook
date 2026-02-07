# Security Audit: Guestbook.sol

**Date**: 2026-02-07  
**Auditor**: Aether (Trail of Bits methodology)  
**Scope**: `src/Guestbook.sol` (57 lines)  
**Tools**: Slither 0.11.5, Foundry (forge test + coverage)

---

## Executive Summary

Guestbook.sol is a simple, non-upgradeable contract with a single state-changing function (`sign`). The attack surface is minimal. No critical or high-severity issues found. The contract has **100% line/statement/function coverage** and **85.71% branch coverage**. Two medium and two low findings are noted below, primarily around gas optimization and Solidity version.

**Overall Risk: LOW** ✅

---

## Entry Points (1 state-changing function)

| Category | Count |
|----------|-------|
| Public (Unrestricted) | 1 |
| Role-Restricted | 0 |
| Contract-Only | 0 |
| **Total** | **1** |

### Public Entry Points (Unrestricted)

| Function | File | Notes |
|----------|------|-------|
| `sign(string calldata)` | `src/Guestbook.sol:22` | Appends entry, increments counter, emits event |

### View Functions (excluded from entry point count)

| Function | File |
|----------|------|
| `totalEntries()` | `src/Guestbook.sol:38` |
| `getLatest(uint256)` | `src/Guestbook.sol:43` |
| `getEntry(uint256)` | `src/Guestbook.sol:55` |
| `entries(uint256)` | Auto-generated getter |
| `entryCount(address)` | Auto-generated getter |

---

## Findings

### MEDIUM-1: Unbounded Array Growth (DoS Risk)

**File**: `src/Guestbook.sol:14` — `Entry[] public entries;`

The `entries` array grows without limit. While `sign()` itself is O(1), `getLatest()` copies entries into memory. As the array grows very large:
- `getLatest(count)` with large `count` will consume increasing gas
- Eventually `getLatest(entries.length)` becomes uncallable (out-of-gas)

**Impact**: View functions become unusable over time. No fund loss risk (no funds held), but affects frontend/dApp usability.

**Recommendation**: 
- This is acceptable for a guestbook (read via events off-chain, not `getLatest`)
- If on-chain reads matter: add pagination (`getRange(uint256 start, uint256 count)`)
- Consider capping max `count` in `getLatest`: `if (count > 100) count = 100;`

**Severity**: MEDIUM (functional degradation, no fund loss)

---

### MEDIUM-2: No Rate Limiting / Spam Protection

**File**: `src/Guestbook.sol:22` — `function sign()`

Any address can call `sign()` unlimited times. A malicious actor could spam thousands of entries cheaply (especially on L2s where gas is near-zero).

**Impact**: Array bloat, event log pollution, UI/UX degradation.

**Recommendation**:
- Add cooldown: `require(block.timestamp - lastSigned[msg.sender] > 1 hours, "Wait")`
- Or require minimum payment: `require(msg.value >= 0.0001 ether, "Fee required")`
- Or cap entries per address: `require(entryCount[msg.sender] < 10, "Max reached")`

**Severity**: MEDIUM (griefing vector, no fund loss)

---

### LOW-1: Solidity Version Constraint

**File**: `src/Guestbook.sol:2` — `pragma solidity ^0.8.20;`

Slither flags: `^0.8.20` includes versions with known compiler bugs:
- VerbatimInvalidDeduplication
- FullInlinerNonExpressionSplitArgumentEvaluationOrder
- MissingSideEffectsOnSelectorAccess

**Impact**: Unlikely to affect this contract (no inline assembly, no verbatim, no selector access side effects). But best practice is to pin to a specific safe version.

**Recommendation**: Pin to `pragma solidity 0.8.28;` or latest stable (currently compiling with 0.8.33).

**Severity**: LOW

---

### LOW-2: Slither False Positive — Timestamp Comparisons

Slither flags `getLatest()` and `getEntry()` for "dangerous timestamp comparisons." These are actually array index comparisons (`count > total`, `i < count`, `id < entries.length`) — not timestamp-dependent logic.

**Impact**: None. False positive.

**Recommendation**: No action needed. Can add `// slither-disable-next-line timestamp` comments for clean reports.

**Severity**: INFORMATIONAL (false positive)

---

## Token Integration Risks

**N/A** — Contract does not interact with external tokens.

---

## Code Maturity Score

| Category | Score | Notes |
|----------|-------|-------|
| Testing | 9/10 | 100% line/stmt/func coverage, 85.71% branch. Missing fuzz tests. |
| Documentation | 8/10 | Good NatSpec on all functions. Missing: system-level README, deployment docs |
| Access Control | 10/10 | No privileged functions, no owner, no admin. Fully permissionless. |
| Error Handling | 9/10 | Clear require messages. No unchecked blocks. |
| Gas Optimization | 7/10 | String storage in array is expensive. Could use events-only pattern. |
| Upgradeability | N/A | Non-upgradeable (good for a guestbook) |
| Dependencies | 10/10 | Zero external dependencies |
| **Overall** | **8.8/10** | Production-ready for its scope |

### Coverage Detail
```
╭-------------------+-----------------+-----------------+--------------+---------------╮
| File              | % Lines         | % Statements    | % Branches   | % Funcs       |
+======================================================================================+
| src/Guestbook.sol | 100.00% (19/19) | 100.00% (19/19) | 85.71% (6/7) | 100.00% (4/4) |
╰-------------------+-----------------+-----------------+--------------+---------------╯
```

The missing branch (1/7 = 14.29%) is likely the `count > total` path in `getLatest` when `count <= total` — test `test_GetLatest` only tests with `count < total`.

---

## Recommended Fuzz Tests

### 1. Fuzz `sign()` with arbitrary strings
```solidity
function testFuzz_Sign(string calldata message) public {
    // Bound to valid length
    vm.assume(bytes(message).length > 0 && bytes(message).length <= 280);
    
    guestbook.sign(message);
    
    // Invariant: entry count always matches
    assertEq(guestbook.totalEntries(), 1);
    Guestbook.Entry memory entry = guestbook.getEntry(0);
    assertEq(entry.message, message);
    assertEq(entry.signer, address(this));
}
```

### 2. Fuzz `getLatest()` count parameter
```solidity
function testFuzz_GetLatest(uint256 count) public {
    // Add some entries first
    guestbook.sign("Entry 1");
    guestbook.sign("Entry 2");
    guestbook.sign("Entry 3");
    
    // Should never revert regardless of count
    Guestbook.Entry[] memory result = guestbook.getLatest(count);
    
    // Invariant: returned length <= min(count, totalEntries)
    assertLe(result.length, guestbook.totalEntries());
    assertLe(result.length, count);
}
```

### 3. Invariant: entryCount always matches actual entries
```solidity
function testFuzz_EntryCountConsistency(address[] calldata signers) public {
    for (uint i = 0; i < signers.length && i < 50; i++) {
        vm.prank(signers[i]);
        guestbook.sign("test");
    }
    
    // Invariant: totalEntries == sum of all operations
    assertEq(guestbook.totalEntries(), min(signers.length, 50));
}
```

---

## Appendix

### Slither Output (Raw)
```
Detector: timestamp (FALSE POSITIVE)
- getLatest: count > total, i < count comparisons
- getEntry: id < entries.length comparison

Detector: solc-version
- ^0.8.20 contains known issues (see LOW-1)

1 contract analyzed, 3 results found
```

### Files Analyzed
- `src/Guestbook.sol` (57 lines, 1 state-changing entry point)

### Methodology
Trail of Bits building-secure-contracts framework:
1. Entry point analysis (Slither + manual)
2. Guidelines review (11 assessment areas)
3. Token integration analysis (N/A)
4. Code maturity scoring
5. Property-based test recommendations
