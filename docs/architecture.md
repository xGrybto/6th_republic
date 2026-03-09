# 6th Republic — Technical Architecture

## Overview

The 6th Republic (6R) is a blockchain-based participatory democracy system built on Solidity. It enables verified citizens to create proposals, delegate their voting power, and cast votes — all on-chain, with transparent and auditable results.

The system is composed of three contracts deployed together and coordinated by a central Orchestrator.

---

## Contract Map

```
                    ┌──────────────────────────────┐
                    │         Orchestrator          │
                    │  (owner / entry point)        │
                    │                               │
                    │  - mintPassport()             │
                    │  - createProposal()           │
                    │  - startVoting()              │
                    │  - voteProposal()             │
                    │  - countVotes()               │
                    └────────────┬─────────────────┘
                                 │ owns & deploys
               ┌─────────────────┴──────────────────┐
               │                                    │
   ┌───────────▼────────────┐        ┌──────────────▼──────────┐
   │      SixRPassport       │        │       SixRProposal       │
   │  ERC-721 SBT (non-      │        │  Proposal lifecycle &    │
   │  transferable)          │        │  vote storage            │
   │                         │        │                          │
   │  - safeMint()           │        │  - create()              │
   │  - hasPassport()        │        │  - startVoting()         │
   │  - pauseContract()      │        │  - vote()                │
   │  - enableDelegatedMode()│        │  - getVoters()           │
   │  - delegateVoteTo()     │        │  - getVote()             │
   │  - revokeVote()         │        │  - getStatus()           │
   └─────────────────────────┘        └──────────────────────────┘
```

**Key design choice:** SixRPassport and SixRProposal are owned by the Orchestrator. All state-mutating calls to these contracts go through the Orchestrator, which enforces cross-contract rules (passport ownership, delegation status) before forwarding.

---

## Roles

| Role | Description |
|---|---|
| **Admin (owner)** | Deploys the Orchestrator. Can mint passports. |
| **Citizen** | Holds a SixRPassport SBT. Can create proposals, vote, and manage delegations. |
| **Delegate** | A citizen who has enabled delegated mode and accepted voting delegations from others. |

---

## SixRPassport — Identity & Delegation

An ERC-721 token modified to be a **Soulbound Token (SBT)**:
- `transferFrom`, `approve`, and `setApprovalForAll` always revert.
- Each address can hold **at most one** passport.
- Metadata (name, surname, nationality, birth date, birth place, height) is stored **fully on-chain** and returned as a Base64-encoded JSON URI via `tokenURI()`.

### Delegation Model

A citizen can delegate their voting power to a **delegate** (another citizen who opted into delegated mode).

```
Citizen A ──── delegateVoteTo(Delegate B) ────► Delegate B
                                                 s_delegatePowers[B]++
                                                 s_representatives[A] = B
```

- A citizen cannot delegate if they are already a delegate themselves.
- A citizen cannot be a delegate and have their vote delegated at the same time.
- Delegations are **frozen during voting periods** (contract is paused by the Orchestrator on `startVoting()`).

### State Variables

| Variable | Type | Description |
|---|---|---|
| `s_representatives` | `mapping(address => address)` | Maps a citizen to their chosen representative. `address(0)` = no delegation. |
| `s_delegatePowers` | `mapping(address => uint256)` | Number of citizens who delegated to this address. |
| `s_delegatedMode` | `mapping(address => bool)` | Whether a citizen is accepting delegations. |
| `paused` | `bool` | Blocks all state changes when true (set during voting). |

---

## SixRProposal — Proposal Lifecycle

Proposals follow a strict state machine:

```
              ┌──────────────────────────────────────────────────────┐
              │                                                      │
              ▼                                                      │
         [ ENDED ]  ──── create() ────►  [ CREATED ]                │
      (default / initial)                    │                      │
                                        startVoting()               │
                                        (after PREPARATION_PERIOD)  │
                                             │                      │
                                             ▼                      │
                                        [ ONGOING ]                 │
                                             │                      │
                                    vote() when VOTING_PERIOD       │
                                    has elapsed → close()           │
                                             │                      │
                                             └──────────────────────┘
```

### Timing

| Period | Duration |
|---|---|
| `PREPARATION_PERIOD` | 10 minutes (between creation and vote opening) |
| `VOTING_PERIOD` | 30 minutes (voting window after `startVoting()`) |

> Note: These values are development defaults and are expected to be adjusted for production (e.g., 1 day / 3 days as described in the project vision).

### Important Implementation Detail

`proposalCounter` starts at **1**. Proposal ID 0 is never created, so its status defaults to `ENDED` (enum zero-value). The `create()` function requires `proposalCounter - 1` to be `ENDED`, which means the very first proposal can always be created without a prior one existing.

Only **one proposal can be active at a time**. A new proposal can only be created once the previous one has reached `ENDED` status.

---

## Vote Counting & Delegation Weighting

Vote counting happens in `Orchestrator.countVotes()` after a proposal is closed.

### Weight Formula

```
For each voter in proposal.votes:
  if voter is in delegatedMode:
    result[vote] += s_delegatePowers[voter] + 1
                 ↑                          ↑
                 delegated citizens         voter's own citizen vote
  else:
    result[vote] += 1
```

A delegate who received 4 delegations and voted YES contributes **5** YES votes (4 delegated + 1 own).

### Vote Enum Values

| Value | uint256 | Meaning |
|---|---|---|
| `NULL` | 0 | Default / not voted (rejected if submitted) |
| `NO` | 1 | Vote against |
| `YES` | 2 | Vote in favor |

---

## Full Voting Flow

```
1. Admin mints passports for citizens via Orchestrator.mintPassport()

2. During preparation:
   - Citizens enable delegated mode (SixRPassport.enableDelegatedMode())
   - Citizens delegate to representatives (SixRPassport.delegateVoteTo())

3. Admin calls Orchestrator.startVoting(proposalId)
   → SixRProposal: proposal status → ONGOING
   → SixRPassport: paused = true (delegations locked)

4. Citizens with no delegation call Orchestrator.voteProposal(proposalId, YES|NO)
   → Delegates vote and carry the weight of their delegators

5. When VOTING_PERIOD has elapsed:
   - The next voteProposal() call triggers automatic closure:
     → SixRProposal.close(): status → ENDED, endBlockHash = blockhash(block.number - 1) recorded
     → SixRPassport: paused = false
     → Orchestrator.countVotes() runs
     → ElectionResult(proposalId, yes, no) emitted

6. A new proposal can now be created
```

---

## Events Reference

| Contract | Event | Trigger |
|---|---|---|
| `Orchestrator` | `ElectionResult(proposalId, yes, no)` | Vote period expired and results counted |
| `SixRPassport` | `MintPassport(passportId, citizen, firstname, lastname)` | New passport minted |
| `SixRPassport` | `DelegatedModeEnabled(citizen)` | Citizen enables delegate mode |
| `SixRPassport` | `DelegatedModeDisabled(citizen)` | Citizen disables delegate mode |
| `SixRPassport` | `DelegationTo(citizen, delegatedCitizen)` | Vote delegated |
| `SixRPassport` | `RevokeDelegationTo(citizen, delegatedCitizen)` | Delegation revoked |
| `SixRProposal` | `Created(proposalId, creator, title)` | New proposal created |
| `SixRProposal` | `VoteStarted(proposalId)` | Voting period opened |
| `SixRProposal` | `Voted(proposalId, voter)` | Vote cast |
| `SixRProposal` | `Ended(proposalId, blockHash)` | Proposal closed |

---

## Open Questions & Known Limitations

- **Identity verification:** No on-chain KYC. The admin is trusted to mint passports only for verified citizens. ZKP-based verification (e.g., Anon Aadhaar, Semaphore) is a potential future path.
- **Domain-specific delegation:** The README describes per-domain delegation (ecology, health, economy, education). This is not yet implemented; the current model supports a single active delegation per citizen.
- **Proposal signatures:** The README mentions a minimum signature requirement before a proposal proceeds to vote. This is not yet implemented in the contracts.
- **Timing:** `PREPARATION_PERIOD` (10 min) and `VOTING_PERIOD` (30 min) are development values. Production values of 1 day / 3 days are described in the project vision.
- **Delegate disabling:** `disableDelegatedMode()` does not automatically revoke existing delegations from citizens who have already delegated to this address.
