# TradFI — läsa marknadsstatus från kedjan (för sajten)

Allt sajten behöver finns som gratis `view`-anrop på `MarketCalendar` — ingen
backend, ingen indexer, bara en RPC.

## Adresser

| Miljö | MarketCalendar | RPC |
|---|---|---|
| Testnet (46630) | `0xdC9A372eFaB73F3D45E01ECE286d6be614a5E693` | `https://rpc.testnet.chain.robinhood.com` (eller Alchemy) |
| Mainnet (4663) | *(sätts vid launch)* | `https://rpc.mainnet.chain.robinhood.com` |

## ABI (bara det sajten behöver)

```json
[
  { "type": "function", "name": "isMarketOpen", "inputs": [], "outputs": [{ "type": "bool" }], "stateMutability": "view" },
  { "type": "function", "name": "nextOpen", "inputs": [{ "name": "timestamp", "type": "uint256" }], "outputs": [{ "type": "uint256" }], "stateMutability": "view" }
]
```

## Exempel (viem)

```ts
import { createPublicClient, http, defineChain } from "viem";

const robinhoodTestnet = defineChain({
  id: 46630,
  name: "Robinhood Chain Testnet",
  nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
  rpcUrls: { default: { http: ["https://rpc.testnet.chain.robinhood.com"] } },
});

const client = createPublicClient({ chain: robinhoodTestnet, transport: http() });
const CAL = "0xdC9A372eFaB73F3D45E01ECE286d6be614a5E693";
const abi = [
  { type: "function", name: "isMarketOpen", inputs: [], outputs: [{ type: "bool" }], stateMutability: "view" },
  { type: "function", name: "nextOpen", inputs: [{ name: "timestamp", type: "uint256" }], outputs: [{ type: "uint256" }], stateMutability: "view" },
] as const;

const open = await client.readContract({ address: CAL, abi, functionName: "isMarketOpen" });
const next = await client.readContract({
  address: CAL, abi, functionName: "nextOpen",
  args: [BigInt(Math.floor(Date.now() / 1000))],
});
// Countdown: Number(next) * 1000 - Date.now()  → "Market opens in 2h 14m 07s"
```

## Tips för countdownen

- `nextOpen(now)` returnerar `now` själv när marknaden är öppen — visa då
  i stället nedräkning till stängning: 16:00 ET vanliga dagar, 13:00 ET
  halvdagar. Enklast: när `isMarketOpen() == true`, polla `isMarketOpen`
  varje minut och visa "MARKET OPEN".
- Räkna ner klientside från ett hämtat värde; hämta om från kedjan vid
  sidladdning och när nedräkningen når noll. Polla inte RPC:n varje sekund.
- Kedjans svar är alltid i UTC-epoch — ingen tidszonslogik behövs i sajten,
  kontraktet har redan gjort DST-jobbet.
- Vid `MarketClosed`-revert från en swap innehåller feldatan nästa öppning:
  selector `0x9dc30b8e` + uint256 (epoch). Kan användas för felmeddelanden i
  ev. egen swap-widget.
```
