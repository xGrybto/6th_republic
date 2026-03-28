# 6th Republic (6R)

> *Bringing participatory democracy on-chain — one proposal, one citizen, one vote.*

---

## Table of Contents

1. [Vision](#vision)
2. [How It Works — Core Principles](#how-it-works--core-principles)
3. [Open Questions & Future Directions](#open-questions--future-directions)
4. [Current Implementation — Draft 4](#current-implementation--draft-4)
5. [EthCC Version](#ethcc-version)

---

## Vision

Modern democracies face a fundamental tension: representative systems are scalable but distant from the people, while direct democracy is participatory but hard to sustain at scale.

The **6th Republic** project explores a third path — a blockchain-based participatory democracy where every citizen has a voice, decisions are transparent, and delegation is flexible and revocable at any time.

By leveraging **smart contracts**, **Soulbound Tokens (SBTs)**, and **Decentralized Autonomous Organization (DAO)** patterns, 6R aims to:

- Make voting **accessible** — no physical travel, no bureaucracy.
- Make results **auditable** — all votes are recorded on-chain.
- Make power **flexible** — citizens can delegate to experts they trust, per topic, and take it back whenever they want.

Here is how a citizen participates in the 6R system:

- Has **one voting power** and **one signature power**.
- Can **create proposals** on any civic topic.
- Can **delegate their vote** to another citizen — who can accumulate voting power.
- May eventually delegate **per domain** (economy, ecology, health, education, etc.) to different experts.
- Can **revoke** any delegation at any time before a vote starts.
- **Cannot delegate** their signature.

A proposal goes through two stages:
1. A **preparation period** — citizens can sign the proposal and manage their delegations.
2. A **voting period** — citizens (and delegates) cast their YES / NO vote.

A proposal requires reaching a minimum number of signatures before it can be put to a vote *(planned — not yet implemented)*.

---

## How It Works — Core Principles

### Citizen Identity

Each citizen holds a **Soulbound Token (SBT)** — a non-transferable NFT that acts as their digital passport. It cannot be sold or given away, ensuring one person = one identity on-chain.

### Delegation

Citizens who don't want to vote on every topic can **delegate their voting power** to a representative they trust. That representative votes on their behalf, carrying the weight of every delegation they've received.

Example: a delegate who received 4 delegations and votes YES contributes **5 YES votes** (4 delegated + 1 own).

Delegations are **frozen once the voting period starts** — ensuring no last-minute power shifts during an active vote.

### Voting

A vote has two possible answers: **YES** or **NO**.

A proposal is considered adopted when the majority votes YES *(exact threshold rules are subject to discussion — see below)*.

Results are computed on-chain and emitted as a public event, visible to anyone.

---

## Open Questions & Future Directions

These are the key design challenges that remain open for discussion and research:

### 🔐 Citizen Identity & Trust
How do we trust a citizen's digital decisions (vote, delegation, signature)?

> **Idea:** Each citizen receives an SBT ID card linked to their physical identity when they create their real-world ID. Every on-chain action requires biometric verification.
>
> Can we trust current KYC models? Alternatives like **Zero-Knowledge Proofs** (e.g., Anon Aadhaar, Semaphore) could allow identity verification without exposing personal data.

### ⚖️ Equal Voting Power
Is a flat "one citizen = one vote" model fair? Should subject-matter experts carry more weight on proposals in their domain?

> How do we define expertise in a fair and decentralized way? This is one of the hardest unsolved problems in participatory governance.

### 🔒 Privacy
How do we protect the privacy of votes, delegations, and signatures?

> **Zero-Knowledge Proofs (ZKPs)** are a natural candidate — allowing a citizen to prove they voted correctly without revealing their choice.

### 🗂️ Domain-Specific Delegation *(planned)*
The vision supports delegating voting power per topic (ecology, economy, health...) to different trusted citizens. The current model supports only one active delegation at a time.

### ✍️ Proposal Signatures *(planned)*
Before a proposal moves to a vote, it should require a minimum number of citizen signatures. This threshold mechanism is not yet implemented.

### ⏱️ Timing Parameters
Production timings (1-day preparation, 3-day voting) are defined in the vision. Current contracts use shorter development values (10 min / 30 min).

---

## Current Implementation — Draft 4

> **Branch:** `main` — **Release:** [v4.0.0](https://github.com/xGrybto/6th_republic/releases/tag/v4.0.0)

Draft 4 is the reference implementation of the 6R system. It introduces an **Orchestrator** contract as the central entry point, coordinating two specialized contracts: the Passport and the Proposal.

### Architecture Overview

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

All state-mutating interactions go through the Orchestrator, which enforces cross-contract rules (passport ownership, delegation status) before forwarding calls.

For the full technical reference, see [`docs/architecture.md`](./docs/architecture.md).

---

### Contracts

#### `SixRPassport` — Digital Identity

A non-transferable ERC-721 token (Soulbound Token) representing a citizen's identity.

- One passport per address, forever linked to its owner.
- Citizen metadata (name, nationality, birth date, etc.) is stored **fully on-chain** and returned as a Base64-encoded JSON URI.
- Supports **delegation** and **delegated mode** — a citizen can opt in to receive delegations from others.
- The contract is **pausable**: delegations are frozen during voting periods.

#### `SixRProposal` — Proposal Lifecycle

Manages the full lifecycle of a civic proposal through a strict state machine:

```
[ ENDED ] ──── create() ────► [ CREATED ] ──── startVoting() ────► [ ONGOING ] ──── close() ────► [ ENDED ]
```

- Only **one proposal can be active at a time**.
- A new proposal can only be created once the previous one has reached `ENDED` status.

| Period | Duration (dev) | Duration (production) |
|---|---|---|
| Preparation | 10 minutes | ~1 day |
| Voting | 30 minutes | ~3 days |

#### `Orchestrator` — Central Coordinator

The single entry point for all citizen interactions. It:

- Mints passports on behalf of verified citizens.
- Enforces passport ownership before allowing any action.
- Triggers vote counting after the voting period closes.
- Emits the final `ElectionResult(proposalId, yes, no)` event.

---

### Voting & Delegation Weight

Vote weight is calculated at the end of the voting period:

```
if voter is in delegatedMode:
    weight = s_delegatePowers[voter] + 1   ← delegated votes + own vote
else:
    weight = 1
```

---

### Proposal Lifecycle — Full Flow

```
1. Admin mints passports for citizens via Orchestrator.mintPassport()

2. Preparation period:
   - Citizens enable delegated mode
   - Citizens delegate their vote to a representative

3. Admin calls startVoting(proposalId)
   → Proposal status: CREATED → ONGOING
   → Passport contract: paused (delegations locked)

4. Citizens vote via Orchestrator.voteProposal(proposalId, YES|NO)
   → Delegates vote and carry the weight of their delegators

5. When the voting period has elapsed:
   → Next voteProposal() call triggers automatic closure
   → Proposal status: ONGOING → ENDED
   → Passport contract: unpaused
   → countVotes() runs → ElectionResult event emitted

6. A new proposal can now be created
```

---

### Key Events

| Contract | Event | Description |
|---|---|---|
| `Orchestrator` | `ElectionResult(proposalId, yes, no)` | Vote results published |
| `SixRPassport` | `MintPassport(passportId, citizen, firstname, lastname)` | New passport minted |
| `SixRPassport` | `DelegationTo(citizen, delegatedCitizen)` | Vote delegated |
| `SixRPassport` | `RevokeDelegationTo(citizen, delegatedCitizen)` | Delegation revoked |
| `SixRProposal` | `Created(proposalId, creator, title)` | New proposal created |
| `SixRProposal` | `VoteStarted(proposalId)` | Voting period opened |
| `SixRProposal` | `Voted(proposalId, voter)` | Vote cast |
| `SixRProposal` | `Ended(proposalId, blockHash)` | Proposal closed |

---

### Known Limitations (Draft 4)

- **No on-chain KYC.** The admin is trusted to mint passports only for verified citizens.
- **Single active delegation per citizen.** Domain-specific delegation is not yet implemented.
- **No signature threshold.** A proposal can be created without prior citizen signatures.
- **`disableDelegatedMode()`** does not automatically revoke existing delegations from citizens who already delegated to that address.

---

## EthCC Version

A dedicated version of 6R has been adapted for live demonstration at **EthCC**. It simplifies the flow to make it usable in a real-event context, with shorter timings, a pre-configured scenario, and a frontend interface.

> 📄 See the dedicated README in the [`draft-ethcc`](https://github.com/xGrybto/6th_republic/tree/draft-ethcc) branch for full details.

---

## Stack

- **Language:** Solidity
- **Framework:** Foundry
- **Libraries:** OpenZeppelin (`ERC721`, `EnumerableMap`, `Pausable`, `Ownable`)

---

*This project is an ongoing experiment in on-chain governance. Contributions, questions, and challenges to the design are welcome.*
