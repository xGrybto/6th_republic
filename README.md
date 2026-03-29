# 6R × EthCC — Smart Contracts

> Live-event adaptation of the [6th Republic](https://github.com/xGrybto/6th_republic) contracts for EthCC · Cannes.
> Frontend: [6th-republic-dapp.vercel.app](https://6th-republic-dapp.vercel.app)

---

## Differences from `main`

### `SixRPassport`

- Metadata reduced to **pseudo + nationality + imageIndex** (name, surname, birth date removed).
- `imageIndex` is pseudo-randomly assigned at mint (`keccak256(block.timestamp, to, tokenId) % imageCount`).
- Image served from an **IPFS folder** configured via `setImageConfig(baseURI, colors[])` before the first mint.

### `Orchestrator`

- `mintPassport()` — **no `onlyOwner`**. Any address can self-mint a passport.
- `createProposal()` — **`onlyOwner`**. Only the admin creates proposals (controlled demo scenario).

### `SixRProposal`

- No changes. `PREPARATION_PERIOD = 10 min`, `VOTING_PERIOD = 30 min` (unchanged from `main` dev values).

---

*Core voting logic, delegation model, and contract architecture are identical to `main`.*
