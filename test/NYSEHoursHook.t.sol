// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {Deployers} from "v4-core/test/utils/Deployers.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {SwapParams, ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {MarketCalendar} from "../src/MarketCalendar.sol";
import {CalendarData2026_2027} from "../src/CalendarData2026_2027.sol";
import {NYSEHoursHook} from "../src/NYSEHoursHook.sol";
import {EtTime} from "./utils/EtTime.sol";

contract NYSEHoursHookTest is Test, Deployers {
    MarketCalendar cal;
    NYSEHoursHook hook;

    // 1% fee pools use tickSpacing 200; align the test liquidity range to it
    ModifyLiquidityParams internal ADD_LIQ =
        ModifyLiquidityParams({tickLower: -600, tickUpper: 600, liquidityDelta: 1e18, salt: 0});
    ModifyLiquidityParams internal REMOVE_LIQ =
        ModifyLiquidityParams({tickLower: -600, tickUpper: 600, liquidityDelta: -1e17, salt: 0});

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        cal = new MarketCalendar(address(this), CalendarData2026_2027.entries());

        address hookAddr = address(uint160(Hooks.BEFORE_SWAP_FLAG));
        deployCodeTo("NYSEHoursHook.sol:NYSEHoursHook", abi.encode(manager, cal), hookAddr);
        hook = NYSEHoursHook(hookAddr);

        (key,) = initPool(currency0, currency1, IHooks(hookAddr), 10000, SQRT_PRICE_1_1);
        // adding liquidity works regardless of market hours (hook does not gate it)
        modifyLiquidityRouter.modifyLiquidity(key, ADD_LIQ, ZERO_BYTES);
    }

    function _ts(uint256 y, uint256 mo, uint256 d, uint256 h, uint256 mi, uint256 s)
        internal
        view
        returns (uint256)
    {
        return EtTime.ts(cal, y, mo, d, h, mi, s);
    }

    function test_swapSucceedsDuringMarketHours() public {
        vm.warp(_ts(2026, 8, 21, 12, 0, 0)); // Fri noon ET
        swap(key, true, -1e15, ZERO_BYTES);
    }

    function test_swapRevertsAfterClose() public {
        vm.warp(_ts(2026, 8, 21, 17, 0, 0));
        vm.expectRevert();
        swap(key, true, -1e15, ZERO_BYTES);
    }

    function test_swapRevertsOnWeekend() public {
        vm.warp(_ts(2026, 8, 22, 12, 0, 0)); // Saturday
        vm.expectRevert();
        swap(key, true, -1e15, ZERO_BYTES);
    }

    function test_swapRevertsOnHoliday() public {
        vm.warp(_ts(2026, 11, 26, 12, 0, 0)); // Thanksgiving
        vm.expectRevert();
        swap(key, true, -1e15, ZERO_BYTES);
    }

    function test_swapRevertsOnHalfDayAfternoon() public {
        vm.warp(_ts(2026, 11, 27, 13, 0, 0));
        vm.expectRevert();
        swap(key, true, -1e15, ZERO_BYTES);
    }

    function test_exactBoundaries() public {
        vm.warp(_ts(2026, 8, 24, 9, 29, 59)); // Monday
        vm.expectRevert();
        swap(key, true, -1e15, ZERO_BYTES);

        vm.warp(_ts(2026, 8, 24, 9, 30, 0));
        swap(key, true, -1e15, ZERO_BYTES);

        vm.warp(_ts(2026, 8, 24, 15, 59, 59));
        swap(key, false, -1e15, ZERO_BYTES);

        vm.warp(_ts(2026, 8, 24, 16, 0, 0));
        vm.expectRevert();
        swap(key, true, -1e15, ZERO_BYTES);
    }

    function test_liquidityOpsWorkWhenMarketClosed() public {
        vm.warp(_ts(2026, 8, 22, 12, 0, 0)); // Saturday
        modifyLiquidityRouter.modifyLiquidity(key, ADD_LIQ, ZERO_BYTES);
        modifyLiquidityRouter.modifyLiquidity(key, REMOVE_LIQ, ZERO_BYTES);
    }

    function test_beforeSwapRevertsForNonPoolManagerCaller() public {
        vm.warp(_ts(2026, 8, 21, 12, 0, 0));
        vm.expectRevert(NYSEHoursHook.NotPoolManager.selector);
        hook.beforeSwap(
            address(this),
            key,
            SwapParams({zeroForOne: true, amountSpecified: -1e15, sqrtPriceLimitX96: 0}),
            ZERO_BYTES
        );
    }

    function test_constructorRejectsWrongFlagAddress() public {
        vm.expectRevert(NYSEHoursHook.InvalidHookAddress.selector);
        new NYSEHoursHook(manager, cal); // deployed to a normal (unflagged) address
    }

    function test_marketClosedErrorCarriesNextOpen() public {
        uint256 closedAt = _ts(2026, 8, 21, 17, 0, 0);
        uint256 expectedOpen = _ts(2026, 8, 24, 9, 30, 0);
        vm.warp(closedAt);
        vm.prank(address(manager));
        vm.expectRevert(abi.encodeWithSelector(NYSEHoursHook.MarketClosed.selector, expectedOpen));
        hook.beforeSwap(
            address(this),
            key,
            SwapParams({zeroForOne: true, amountSpecified: -1e15, sqrtPriceLimitX96: 0}),
            ZERO_BYTES
        );
    }
}
