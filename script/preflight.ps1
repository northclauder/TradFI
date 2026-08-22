# TradFI preflight - verify chain infrastructure before any deploy.
# Usage:  .\script\preflight.ps1 -Rpc <url> [-Deployer <address>]
# Checks the lesson learned in the testnet rehearsal: every address must have
# bytecode, and WETH must actually behave like WETH9, BEFORE anything is sent.
param(
    [Parameter(Mandatory = $true)][string]$Rpc,
    [string]$Deployer,
    [string]$PoolManager = '0x8366a39CC670B4001A1121B8F6A443A643e40951',
    [string]$PositionManager = '0x58daec3116aae6d93017baaea7749052e8a04fa7',
    [string]$Permit2 = '0x000000000022D473030F116dDEE9F6B43aC78BA3',
    [string]$Weth = ''
)

$fail = $false
function Check($name, $ok, $detail) {
    $mark = if ($ok) { 'OK  ' } else { $script:fail = $true; 'FAIL' }
    Write-Host ("[$mark] $name" + $(if ($detail) { " - $detail" } else { '' }))
}

$chainId = cast chain-id --rpc-url $Rpc
Check 'RPC svarar' ($LASTEXITCODE -eq 0) "chain id $chainId"

foreach ($c in @(
    @{ n = 'PoolManager'; a = $PoolManager },
    @{ n = 'PositionManager'; a = $PositionManager },
    @{ n = 'Permit2'; a = $Permit2 })) {
    $code = cast code $c.a --rpc-url $Rpc
    Check ($c.n + ' har bytecode') ($code.Length -gt 4) $c.a
}

# WETH: default to asking the PositionManager, but ALWAYS verify bytecode -
# on testnet posm.WETH9() points at an address with no contract.
if (-not $Weth) {
    $Weth = cast call $PositionManager "WETH9()(address)" --rpc-url $Rpc
    Write-Host "      (WETH fran posm.WETH9(): $Weth)"
}
$wcode = cast code $Weth --rpc-url $Rpc
Check 'WETH har bytecode' ($wcode.Length -gt 4) $Weth
if ($wcode.Length -gt 4) {
    $sym = cast call $Weth "symbol()(string)" --rpc-url $Rpc
    Check 'WETH symbol' ($sym -match 'WETH') $sym
    Check 'WETH deposit()-selector' ($wcode -match 'd0e30db0') 'd0e30db0'
    $dec = cast call $Weth "decimals()(uint8)" --rpc-url $Rpc
    Check 'WETH decimals = 18' ($dec -eq '18') $dec
}

if ($Deployer) {
    $bal = cast balance $Deployer --rpc-url $Rpc --ether
    Check 'Deployer ETH-saldo > 0' ([double]$bal -gt 0) "$bal ETH"
    if ($wcode.Length -gt 4) {
        $wbal = cast call $Weth "balanceOf(address)(uint256)" $Deployer --rpc-url $Rpc
        Write-Host "      Deployer WETH-saldo: $wbal"
    }
}

Write-Host ''
if ($fail) { Write-Host 'PREFLIGHT FAILED - deploya INTE.' -ForegroundColor Red; exit 1 }
else { Write-Host 'PREFLIGHT OK.' -ForegroundColor Green }
