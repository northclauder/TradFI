// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {ModifyLiquidityParams, SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {BeforeSwapDelta, BeforeSwapDeltaLibrary} from "v4-core/src/types/BeforeSwapDelta.sol";
import {MarketCalendar} from "./MarketCalendar.sol";

/// @notice Uniswap v4 hook that reverts swaps outside NYSE trading hours.
///         Only `beforeSwap` is active; liquidity operations are never gated so
///         the permanent LP lock keeps working around the clock. The contract
///         must be deployed to an address whose flag bits are exactly
///         BEFORE_SWAP_FLAG (mined via CREATE2).
contract NYSEHoursHook is IHooks {
    IPoolManager public immutable poolManager;
    MarketCalendar public immutable calendar;

    error MarketClosed(uint256 nextOpen);
    error HookNotImplemented();
    error InvalidHookAddress();
    error NotPoolManager();

    constructor(IPoolManager poolManager_, MarketCalendar calendar_) {
        poolManager = poolManager_;
        calendar = calendar_;
        if (uint160(address(this)) & Hooks.ALL_HOOK_MASK != Hooks.BEFORE_SWAP_FLAG) {
            revert InvalidHookAddress();
        }
    }

    /// @inheritdoc IHooks
    function beforeSwap(address, PoolKey calldata, SwapParams calldata, bytes calldata)
        external
        view
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (msg.sender != address(poolManager)) revert NotPoolManager();
        if (!calendar.isMarketOpenAt(block.timestamp)) {
            revert MarketClosed(calendar.nextOpen(block.timestamp));
        }
        return (IHooks.beforeSwap.selector, BeforeSwapDeltaLibrary.ZERO_DELTA, 0);
    }

    // --- Unused callbacks: never invoked (address flags gate them), revert defensively ---

    function beforeInitialize(address, PoolKey calldata, uint160) external pure returns (bytes4) {
        revert HookNotImplemented();
    }

    function afterInitialize(address, PoolKey calldata, uint160, int24) external pure returns (bytes4) {
        revert HookNotImplemented();
    }

    function beforeAddLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterAddLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function beforeRemoveLiquidity(address, PoolKey calldata, ModifyLiquidityParams calldata, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterRemoveLiquidity(
        address,
        PoolKey calldata,
        ModifyLiquidityParams calldata,
        BalanceDelta,
        BalanceDelta,
        bytes calldata
    ) external pure returns (bytes4, BalanceDelta) {
        revert HookNotImplemented();
    }

    function afterSwap(address, PoolKey calldata, SwapParams calldata, BalanceDelta, bytes calldata)
        external
        pure
        returns (bytes4, int128)
    {
        revert HookNotImplemented();
    }

    function beforeDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert HookNotImplemented();
    }

    function afterDonate(address, PoolKey calldata, uint256, uint256, bytes calldata)
        external
        pure
        returns (bytes4)
    {
        revert HookNotImplemented();
    }
}
