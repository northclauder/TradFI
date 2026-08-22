// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {MarketCalendar} from "../src/MarketCalendar.sol";

/// @notice Rehearsal helper: buy TRADFI with WETH in the deployed pool.
///
/// Env vars:
///   POOL_MANAGER, WETH, TRADFI, HOOK, CALENDAR - deployed addresses
///   SWAP_AMOUNT  - WETH in (wei), e.g. 100000000000000 = 0.0001 WETH
///   SWAP_ROUTER  - optional; reuse an already-deployed PoolSwapTest router
///
/// The script warns (but proceeds) if the market is closed, so it can also be
/// used to demonstrate the MarketClosed revert on-chain.
contract SwapTestScript is Script {
    function run() external {
        IPoolManager poolManager = IPoolManager(vm.envAddress("POOL_MANAGER"));
        address weth = vm.envAddress("WETH");
        address tradfi = vm.envAddress("TRADFI");
        address hook = vm.envAddress("HOOK");
        MarketCalendar calendar = MarketCalendar(vm.envAddress("CALENDAR"));
        uint256 amountIn = vm.envUint("SWAP_AMOUNT");

        bool open = calendar.isMarketOpen();
        console2.log("Market open?", open);
        if (!open) {
            console2.log("NOTE: market is CLOSED - the swap should revert. Next open:");
            console2.log(calendar.nextOpen(block.timestamp));
        }

        bool tokenIs0 = tradfi < weth;
        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(tokenIs0 ? tradfi : weth),
            currency1: Currency.wrap(tokenIs0 ? weth : tradfi),
            fee: 10000,
            tickSpacing: 200,
            hooks: IHooks(hook)
        });
        // WETH in: zeroForOne iff WETH is currency0
        bool zeroForOne = !tokenIs0;

        vm.startBroadcast();
        PoolSwapTest router;
        address existing = vm.envOr("SWAP_ROUTER", address(0));
        if (existing == address(0)) {
            router = new PoolSwapTest(poolManager);
            console2.log("Deployed PoolSwapTest router:", address(router));
        } else {
            router = PoolSwapTest(existing);
        }

        IERC20(weth).approve(address(router), type(uint256).max);
        IERC20(tradfi).approve(address(router), type(uint256).max);

        uint256 tradfiBefore = IERC20(tradfi).balanceOf(msg.sender);
        router.swap(
            key,
            SwapParams({
                zeroForOne: zeroForOne,
                amountSpecified: -int256(amountIn),
                sqrtPriceLimitX96: zeroForOne
                    ? TickMath.MIN_SQRT_PRICE + 1
                    : TickMath.MAX_SQRT_PRICE - 1
            }),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
        vm.stopBroadcast();

        console2.log("TRADFI received:", IERC20(tradfi).balanceOf(msg.sender) - tradfiBefore);
    }
}
