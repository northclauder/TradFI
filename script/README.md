# TradFI deploy runbook

The launch is **one broadcast** (`script/Deploy.s.sol`), and the position is
minted **directly to LPLock** — unlocked liquidity never exists at any point.
The exact sequence is integration-tested in `test/DeployFlow.t.sol`.

## Sequence (what the script does)

1. Deploy `MarketCalendar`, seeded with the official NYSE 2026–2027 calendar,
   owned by `OWNER`.
2. Mine a CREATE2 salt (HookMiner) and deploy `NYSEHoursHook` to an address
   whose flag bits are exactly `BEFORE_SWAP_FLAG`.
3. Deploy `TradFI` (1,792,000,000 supply to the broadcaster) and `LPLock`.
4. Initialize the 1% TRADFI/WETH v4 pool with the hook, approve via Permit2,
   and mint the full-range position **with LPLock as recipient**.
5. Register the lock (`lock.lock(tokenId)`) and burn leftover rounding dust to
   `0xdead`. If more than 1% of supply would be left over, the whole deploy
   reverts (`TooMuchDust`) — that means `SQRT_PRICE_X96` and `WETH_AMOUNT`
   are inconsistent.

## SQRT_PRICE_X96 is optional

Leave it unset: the script derives the initial price from `WETH_AMOUNT` vs the
full token supply *after* the token address is known, so the seed is dust-free
by construction and the sort-order footgun disappears. Only set it explicitly
if you want an initial price that differs from the seeded ratio (then the
`TooMuchDust` guard still protects against gross mismatch).

## Verified addresses (checked on-chain 2026-08-21)

Uniswap v4 uses the SAME addresses on Robinhood Chain mainnet (4663) and
testnet (46630) — deterministic deployments, verified by probing both RPCs:

| Contract | Address |
|---|---|
| PoolManager | `0x8366a39CC670B4001A1121B8F6A443A643e40951` |
| PositionManager | `0x58daec3116aae6d93017baaea7749052e8a04fa7` |
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| WETH9 | `0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73` |

(WETH9 read from `PositionManager.WETH9()` on both networks. Re-verify before
mainnet broadcast anyway.)

**WARNING — learned in rehearsal:** `PositionManager.WETH9()` on TESTNET points
at the mainnet WETH address, where no contract exists on testnet. Always verify
`cast code <WETH> --rpc-url <rpc>` returns bytecode before wrapping/deploying.
The actual, verified testnet WETH is `0x33e4191705c386532ba27cBF171Db86919200B94`.

## Testnet rehearsal record (2026-08-22, chain 46630)

Deployed and verified on-chain — all checks passed (closed-Saturday gate,
`MarketClosed(nextOpen)` revert via eth_call as PoolManager, position locked in
LPLock, deployer supply 0, dust burned):

| Contract | Address |
|---|---|
| TradFI | `0x31200377343522Bf566d3627768b9CcDb26bfFf4` |
| MarketCalendar | `0xdC9A372eFaB73F3D45E01ECE286d6be614a5E693` |
| NYSEHoursHook | `0x4e0279E43bE4C61Ee09654c5261f2C0882080080` |
| LPLock | `0x50Ba6AC66A43194530905F646b49b6aFe8F83978` |
| Position tokenId | 1166 |

Remaining rehearsal step: a real swap during market hours (Mon 9:30 ET+),
e.g. via the testnet Universal Router or a PoolSwapTest router.

## Testnet rehearsal (do this first)

PowerShell (RPC read from `.env`, key via foundry keystore):

```powershell
$env:POOL_MANAGER='0x8366a39CC670B4001A1121B8F6A443A643e40951'
$env:POSITION_MANAGER='0x58daec3116aae6d93017baaea7749052e8a04fa7'
$env:PERMIT2='0x000000000022D473030F116dDEE9F6B43aC78BA3'
$env:WETH='0x0Bd7D308f8E1639FAb988df18A8011f41EAcAD73'
$env:WETH_AMOUNT='100000000000000000'   # 0.1 WETH for rehearsal
$rpc = (Get-Content .env | Where-Object { $_ -match '^RPC_ROBINHOOD_TESTNET=' }).Substring(22)
forge script script/Deploy.s.sol --rpc-url $rpc --account tradfi-testnet --broadcast -vvv
```

The broadcaster needs testnet ETH for gas plus 0.1 wrapped WETH
(`cast send $env:WETH "deposit()" --value 0.1ether ...` wraps native ETH).

Then, on the testnet deployment, verify by hand:
- swap succeeds during NYSE hours, reverts with `MarketClosed(nextOpen)` outside
- `collectFees` sends fees to OWNER
- position NFT is owned by LPLock and cannot be moved

## Mainnet (Robinhood Chain)

Same commands with mainnet addresses. The canonical Uniswap v4 addresses for
Robinhood Chain are published in Uniswap's deployments documentation — verify
them from at least two sources before exporting.

After broadcast:

```
forge verify-contract <addr> src/TradFI.sol:TradFI --chain <id> --watch
forge verify-contract <addr> src/MarketCalendar.sol:MarketCalendar --chain <id> --watch
forge verify-contract <addr> src/NYSEHoursHook.sol:NYSEHoursHook --chain <id> --watch
forge verify-contract <addr> src/LPLock.sol:LPLock --chain <id> --watch
```

(Constructor args: `forge verify-contract --help`; use `--constructor-args
$(cast abi-encode ...)`.)

## Key handling

- No private keys in this repo, in env files, or in chat — ever.
- Use `--account` (foundry keystore) or `--ledger`.
- `OWNER` should eventually be a multisig; both `MarketCalendar` and `LPLock`
  are `Ownable` and transferable.

## Yearly maintenance

Each year (well before Jan 1), the owner calls
`setCalendar(year, entries)` with the next year's NYSE calendar. The contract
refuses same-year edits, so don't wait until January — set year N+1 during
year N. If the calendar ever lapses, weekdays simply count as open
(no holidays) until data is added again.
