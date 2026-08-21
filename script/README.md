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

## Choosing SQRT_PRICE_X96

`sqrtPriceX96 = sqrt(price) * 2^96`, where `price = currency1/currency0` in the
**sorted** pair (lower address = currency0). Whether TRADFI is currency0 depends
on its deployed address, which depends on the broadcaster nonce. Compute the
token address ahead of time (`vm.computeCreateAddress` in chisel, or run the
script's simulation first — it prints all addresses without broadcasting), then
derive the price so that `WETH_AMOUNT` matches the full token supply at that
price. Sanity check: the simulation must NOT revert with `TooMuchDust`.

## Testnet rehearsal (do this first)

```
export RPC_URL=<robinhood chain testnet rpc>
export POOL_MANAGER=<v4 PoolManager on testnet>
export POSITION_MANAGER=<v4 PositionManager on testnet>
export PERMIT2=0x000000000022D473030F116dDEE9F6B43aC78BA3
export WETH=<WETH on testnet>
export WETH_AMOUNT=<wei>
export SQRT_PRICE_X96=<price>
forge script script/Deploy.s.sol --rpc-url $RPC_URL --account <keystore> --broadcast -vvv
```

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
