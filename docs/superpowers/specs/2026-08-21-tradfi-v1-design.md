# TradFI V1 — Designspec

**Datum:** 2026-08-21
**Status:** Godkänd design, väntar på spec-granskning
**Ägare:** Leo (leojankovic10@gmail.com)

## Koncept

TRADFI är en memecoin på Robinhood Chain (Arbitrum Orbit EVM L2) som endast kan
handlas när New York-börsen är öppen: 9:30–16:00 ET, måndag–fredag, stängd på
NYSE-helgdagar och med 13:00-stängning på NYSE-halvdagar. Utanför öppettid
revertar alla swappar i poolen med `MarketClosed(nextOpenTimestamp)`.
Mekaniken är memen.

## Beslut (med motivering)

1. **Gate i Uniswap v4-hooken, inte i token-kontraktet.**
   Terminalernas säkerhetsscanners (DEX Screener, DEXTools, GoPlus m.fl.)
   simulerar köp+sälj; en token vars transfers revertar utanför börstid skulle
   flaggas som honeypot. En ren ERC-20 + pool-gate ger samma praktiska effekt
   (all likviditet sitter i vår låsta pool) utan flaggrisk. Wallet-till-wallet-
   transfers fungerar dygnet runt — acceptabel trohetsförlust.
2. **Ingen orderkö/opening auction i V1.** `beforeSwap` kan bara släppa igenom
   eller neka. En kö kräver escrow (custody-risk, MEV, batchauktionslogik) och
   flerdubblar scopet. Wicken vid open uppstår ändå organiskt av uppdämt tryck.
   "Opening Bell Auction" är en möjlig V2 som byggs som fristående router
   ovanpå poolen utan ändringar i V1-kontrakten.
3. **Full NYSE-trohet i kalendern:** helgdagar OCH halvdagar. Admin kan endast
   sätta kalenderdata för framtida år — aldrig innevarande dag/år. Marknaden
   kan därmed aldrig manipuleras same-day.
4. **Fair launch, fees till teamet.** 100% av supply i poolen vid launch,
   LP-positionen permanent låst, swap-avgifterna (1%) claimbara av teamet som
   enda intäkt. Transparent från dag 1.
5. **Supply: 1 792 000 000 TRADFI** — NYSE grundades 1792 (Buttonwood-avtalet).

## Arkitektur

Tre kärnkontrakt plus ett låskontrakt. Solidity, Foundry, OpenZeppelin +
Uniswap v4-core/-periphery.

### TradFI.sol (ERC-20)

- OpenZeppelin ERC-20, namn `TradFI`, symbol `TRADFI`, 18 decimaler.
- Hela supplyn (1 792 000 000e18) mintas till deployern i konstruktorn.
- Ingen mint därefter, ingen tax, inga transfer-hooks, ingen owner.
  Avsiktligt maximalt tråkig så att scanners inte hittar något.

### MarketCalendar.sol

- `isMarketOpen() → bool` samt `isMarketOpen(uint256 timestamp) → bool` (view).
- `nextOpen(uint256 timestamp) → uint256` — nästa öppningstidpunkt, används i
  hookens revert-meddelande och av frontends för countdown.
- **ET-beräkning on-chain:** UTC-offset är −5 (EST) eller −4 (EDT). DST:
  från kl. 02:00 lokal tid andra söndagen i mars till 02:00 första söndagen i
  november, beräknas deterministiskt från timestampen (ingen oracle).
- **Öppettider:** mån–fre 9:30:00–15:59:59 ET inklusive (stängning vid
  16:00:00). Halvdagar stänger 13:00:00 ET.
- **Kalenderlagring:** mapping från datum (år/månad/dag) till status
  (helgdag | halvdag). Admin-funktion `setCalendar(year, entries[])` som
  **revertar om `year` ≤ innevarande år** (innevarande år bestäms av
  block.timestamp i ET). Deployas med 2026–2027 ifyllt.
- **Fallback:** datum utan kalenderpost och bortom sista ifyllda år räknas som
  vanlig handelsdag (vardagar öppna). Memen överlever om admin försvinner;
  troheten degraderar bara till "inga helgdagar".
- Admin är en vanlig `owner` (Leos wallet initialt, multisig senare).
  Owner kan överföras och renouncas.

### NYSEHoursHook.sol (Uniswap v4-hook)

- Endast `beforeSwap`-flaggan satt. Revertar med `MarketClosed(uint256 nextOpen)`
  när `!calendar.isMarketOpen()`.
- Likviditetsoperationer (add/remove) gate:as INTE — låset och ev. framtida
  fee-mekanik måste fungera oavsett tid.
- Kalenderadressen sätts immutable i konstruktorn.
- Hook-adressen minas via CREATE2-salt så att adressens flaggbitar matchar
  `BEFORE_SWAP_FLAG` (standard v4-procedur).

### LPLock.sol

- Äger LP-positionen för evigt: ingen withdraw-, decrease- eller
  transfer-funktion för positionen.
- `collectFees(address to)` — endast owner; skickar intjänade swap-avgifter
  till angiven adress. Enda muterande funktionen.
- Exakt mekanik (PositionManager-NFT vs. direkt PoolManager-position) avgörs i
  implementationsplanen efter kontroll av v4-periphery-versionen på
  Robinhood Chain.

## Pool

- Par: TRADFI/WETH. Fee: 1% (10000). Full range. Hook: NYSEHoursHook.
- Skapas och seedas med 100% av supply + initial WETH **atomiskt i samma
  transaktion som låsningen** (deploy-skript), så det aldrig existerar olåst
  likviditet en enda block.

## Dataflöde

Swap → PoolManager → `beforeSwap` → `MarketCalendar.isMarketOpen()` →
öppen: swappen fortsätter normalt / stängd: revert `MarketClosed(nextOpen)`.
Ingen keeper, ingen oracle, inga externa beroenden — allt är ren view-logik
per swap.

## Terminal-synlighet (verifierat 2026-08-21)

- DEX Screener indexerar Robinhood Chain automatiskt (dexscreener.com/robinhood);
  par med likviditet + trades dyker upp utan ansökan.
- GeckoTerminal listar redan Uniswap v4-pooler på Robinhood Chain.
- DEXTools har förstapartsstöd sedan juli 2026.
- Indexerare läser swap-events; hook-reverts stör inte indexering. Charten får
  naturliga gap utanför börstid — som ett aktiechart. Önskad effekt.
- Vid launch: köp DEX Screener token-update (logga/socials).

## Felhantering

- `MarketClosed(uint256 nextOpen)` — custom error, billig och frontend-läsbar.
- `setCalendar` för icke-framtida år → revert `CalendarYearNotFuture()`.
- Ogiltiga kalenderposter (t.ex. datum som inte existerar) → revert vid set.
- Fallback vid kalender-slut är medveten design, inte ett fel (se ovan).

## Testning (Foundry — kärnan i arbetsveckan)

- **DST-kanter:** sekunden före/efter övergång i mars och november, inkl. att
  övergången sker 02:00 *lokal* tid; åren 2026–2030.
- **Öppning/stängning exakt:** 9:29:59 stängd, 9:30:00 öppen, 15:59:59 öppen,
  16:00:00 stängd; halvdag 12:59:59 öppen, 13:00:00 stängd.
- **Helgdagar:** hela NYSE-kalendern 2026, inkl. observerade dagar
  (helgdag på helg → flyttad fredag/måndag), Good Friday.
- **Skottår** och månadsgränser.
- **Fuzz:** godtyckliga timestamps mot en referensimplementation i testet.
- **Kalender-admin:** framtida år ok, innevarande/passerat år revertar,
  ownership-flöden.
- **Hook-integration:** v4 PoolManager lokalt — swap går igenom under öppettid,
  revertar utanför, add/remove liquidity fungerar alltid.
- **Fork-test mot Robinhood Chain:** riktiga swappar genom hooken mot
  kedjans faktiska PoolManager.
- **LPLock:** positionen kan aldrig tas ut; collectFees fungerar och är
  owner-gated.

## Deploy-sekvens (körs först på testnet, sedan mainnet)

1. Deploya `MarketCalendar` med 2026–2027 ifyllt.
2. Mina CREATE2-salt, deploya `NYSEHoursHook`.
3. Deploya `TradFI` (hela supplyn till deployern).
4. Deploya `LPLock`.
5. En atomisk transaktion: skapa pool → seeda 100% supply + WETH → positionen
   direkt till `LPLock`.
6. Verifiera kontrakten på kedjans explorer.

Nycklar genereras och hålls av Leo. Inga nycklar i repo, inga i den här
konversationen.

## Utanför scope (V1)

- Webbsajt med countdown ("Market opens in 2h 14m").
- Opening Bell Auction (V2 — fristående escrow/batch-router).
- Multisig-migrering av calendar-owner och LPLock-owner.
- Marknadsföring, socials, DEX Screener-metadata (görs vid launch, ej kod).

## Risker

- v4-hookutveckling har skarpa kanter (flaggbitar, delta-hantering) —
  mitigeras med fork-tester och att hooken endast använder beforeSwap utan
  delta-modifiering.
- Lågvolymsdagar ser "döda" ut på charten p.g.a. gap — accepterat, del av memen.
- Fee-claims är synliga on-chain — kommuniceras öppet från start.
- Admin-nyckeln kan sätta framtida års kalender illvilligt (t.ex. markera alla
  dagar som helgdag nästa år) — mitigeras med multisig och att communityn kan
  läsa kalendern on-chain långt i förväg.
