# TradFI — the memecoin that keeps banker's hours

TRADFI trades **only when the NYSE is open**: 9:30–16:00 ET, Monday–Friday,
closed on NYSE holidays, 13:00 close on half days. Outside those hours every
swap reverts with `MarketClosed(nextOpen)`. Sorry, market's closed.

Chain: **Robinhood Chain** (chain id 4663). Venue: **Uniswap v4**.
Supply: **1,792,000,000** (the NYSE was founded in 1792). Fair launch: 100% of
supply in the pool, LP permanently locked, 1% swap fee collectable by the team.

## Contracts

| Contract | Purpose |
|---|---|
| [`src/TradFI.sol`](src/TradFI.sol) | Plain OZ ERC-20. No tax, no owner, no tricks — scanner-proof by design. |
| [`src/MarketCalendar.sol`](src/MarketCalendar.sol) | `isMarketOpen()` on-chain: UTC→ET with deterministic DST, stored NYSE holidays/half-days, `nextOpen()` for countdowns. Admin can only set **future** years. |
| [`src/CalendarData2026_2027.sol`](src/CalendarData2026_2027.sol) | Official NYSE 2026–2027 calendar (verified against the NYSE Group announcement). |
| [`src/NYSEHoursHook.sol`](src/NYSEHoursHook.sol) | v4 hook, `beforeSwap` only: reverts outside market hours. Liquidity ops are never gated. |
| [`src/LPLock.sol`](src/LPLock.sol) | Holds the LP position forever. Owner's only power: `collectFees`. |

## Develop

```bash
forge test          # 68 tests: DST edges, full 2026 day sweep, v4 integration, deploy flow
```

Fork test against the real Robinhood Chain PoolManager (needs a keyed RPC —
the public endpoint blocks non-browser clients):

```bash
RUN_FORK=1 RPC_ROBINHOOD=<url> forge test --match-contract ForkTest
```

## Deploy

See [`script/README.md`](script/README.md). One broadcast; the position is
minted directly into the lock — unlocked liquidity never exists.

## Design docs

- Spec: [`docs/superpowers/specs/2026-08-21-tradfi-v1-design.md`](docs/superpowers/specs/2026-08-21-tradfi-v1-design.md)
- Plan: [`docs/superpowers/plans/2026-08-21-tradfi-v1.md`](docs/superpowers/plans/2026-08-21-tradfi-v1.md)
