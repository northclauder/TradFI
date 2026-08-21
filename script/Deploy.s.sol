// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {DeployLib} from "./DeployLib.sol";

/// @notice TradFI launch script. See script/README.md for the runbook.
///
/// Required env vars:
///   POOL_MANAGER      - Uniswap v4 PoolManager on the target chain
///   POSITION_MANAGER  - Uniswap v4 PositionManager on the target chain
///   PERMIT2           - Permit2 (canonical: 0x000000000022D473030F116dDEE9F6B43aC78BA3)
///   WETH              - wrapped native token to pair against
///   WETH_AMOUNT       - initial liquidity in WETH wei
///   SQRT_PRICE_X96    - initial pool price (for the SORTED currency pair!)
///   OWNER             - calendar admin + fee collector (defaults to broadcaster)
///
/// The broadcaster must hold WETH_AMOUNT of WETH. Never put a private key in
/// this repo — sign with `--account <keystore>` or `--ledger`.
contract DeployScript is Script {
    // forge's deterministic CREATE2 deployer, used for `new X{salt: ...}` in scripts
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        DeployLib.Params memory p = DeployLib.Params({
            owner: vm.envOr("OWNER", msg.sender),
            poolManager: IPoolManager(vm.envAddress("POOL_MANAGER")),
            positionManager: IPositionManager(payable(vm.envAddress("POSITION_MANAGER"))),
            permit2: IAllowanceTransfer(vm.envAddress("PERMIT2")),
            weth: IERC20(vm.envAddress("WETH")),
            wethAmount: vm.envUint("WETH_AMOUNT"),
            sqrtPriceX96: uint160(vm.envUint("SQRT_PRICE_X96")),
            create2Deployer: CREATE2_DEPLOYER
        });

        vm.startBroadcast();
        DeployLib.Result memory r = DeployLib.run(p);
        DeployLib.burnDust(r.token, msg.sender);
        vm.stopBroadcast();

        console2.log("TradFI token:    ", address(r.token));
        console2.log("MarketCalendar:  ", address(r.calendar));
        console2.log("NYSEHoursHook:   ", address(r.hook));
        console2.log("LPLock:          ", address(r.lock));
        console2.log("Position tokenId:", r.tokenId);
        console2.log("Market open now? ", r.calendar.isMarketOpenAt(block.timestamp));
        console2.log("Next open:       ", r.calendar.nextOpen(block.timestamp));
    }
}
