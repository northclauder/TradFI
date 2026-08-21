// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {ModifyLiquidityParams} from "v4-core/src/types/PoolOperation.sol";
import {PoolSwapTest} from "v4-core/src/test/PoolSwapTest.sol";
import {PoolModifyLiquidityTest} from "v4-core/src/test/PoolModifyLiquidityTest.sol";
import {SwapParams} from "v4-core/src/types/PoolOperation.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {HookMiner} from "v4-periphery/test/shared/HookMiner.sol";

import {MarketCalendar} from "../src/MarketCalendar.sol";
import {CalendarData2026_2027} from "../src/CalendarData2026_2027.sol";
import {NYSEHoursHook} from "../src/NYSEHoursHook.sol";
import {TradFI} from "../src/TradFI.sol";
import {EtTime} from "./utils/EtTime.sol";

/// @notice Fork test against the real Robinhood Chain PoolManager. Gated behind
///         RUN_FORK=1 so normal test runs stay offline:
///         RUN_FORK=1 RPC_ROBINHOOD=<url> forge test --match-contract ForkTest
///         NOTE: the public RPC (rpc.mainnet.chain.robinhood.com) sits behind
///         Cloudflare bot protection and rejects forge with HTTP 403 — use a
///         provider RPC with an API key (Alchemy/Dwellir/etc).
contract ForkTest is Test {
    // Canonical Uniswap v4 on Robinhood Chain (chain id 4663), per
    // developers.uniswap.org/docs/protocols/v4/deployments (fetched 2026-08-21)
    IPoolManager constant POOL_MANAGER = IPoolManager(0x8366a39CC670B4001A1121B8F6A443A643e40951);

    MarketCalendar cal;
    NYSEHoursHook hook;
    TradFI token;
    MockERC20 quote;
    PoolSwapTest swapRouter;
    PoolModifyLiquidityTest liqRouter;
    PoolKey key;

    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function setUp() public {
        if (vm.envOr("RUN_FORK", uint256(0)) == 0) {
            vm.skip(true);
            return;
        }
        string memory rpc =
            vm.envOr("RPC_ROBINHOOD", string("https://rpc.mainnet.chain.robinhood.com"));
        vm.createSelectFork(rpc);

        cal = new MarketCalendar(address(this), CalendarData2026_2027.entries());
        (address hookAddr, bytes32 salt) = HookMiner.find(
            address(this),
            uint160(Hooks.BEFORE_SWAP_FLAG),
            type(NYSEHoursHook).creationCode,
            abi.encode(POOL_MANAGER, cal)
        );
        hook = new NYSEHoursHook{salt: salt}(POOL_MANAGER, cal);
        assertEq(address(hook), hookAddr);

        token = new TradFI();
        quote = new MockERC20("Mock Quote", "MQ", 18);
        quote.mint(address(this), 1_000_000e18);

        swapRouter = new PoolSwapTest(POOL_MANAGER);
        liqRouter = new PoolModifyLiquidityTest(POOL_MANAGER);
        token.approve(address(swapRouter), type(uint256).max);
        token.approve(address(liqRouter), type(uint256).max);
        quote.approve(address(swapRouter), type(uint256).max);
        quote.approve(address(liqRouter), type(uint256).max);

        bool tokenIs0 = address(token) < address(quote);
        key = PoolKey({
            currency0: Currency.wrap(tokenIs0 ? address(token) : address(quote)),
            currency1: Currency.wrap(tokenIs0 ? address(quote) : address(token)),
            fee: 10000,
            tickSpacing: 200,
            hooks: IHooks(address(hook))
        });
        POOL_MANAGER.initialize(key, SQRT_PRICE_1_1);
        liqRouter.modifyLiquidity(
            key,
            ModifyLiquidityParams({tickLower: -887200, tickUpper: 887200, liquidityDelta: 1e21, salt: 0}),
            ""
        );
    }

    function _swap() internal {
        swapRouter.swap(
            key,
            SwapParams({zeroForOne: true, amountSpecified: -1e18, sqrtPriceLimitX96: 4295128740}),
            PoolSwapTest.TestSettings({takeClaims: false, settleUsingBurn: false}),
            ""
        );
    }

    function test_fork_swapDuringHoursSucceeds() public {
        vm.warp(EtTime.ts(cal, 2026, 8, 21, 12, 0, 0));
        _swap();
    }

    function test_fork_swapOutsideHoursReverts() public {
        vm.warp(EtTime.ts(cal, 2026, 8, 22, 12, 0, 0)); // Saturday
        vm.expectRevert();
        _swap();
    }

    function test_fork_realClockGatesCorrectly() public {
        // no warp: the fork's real block timestamp decides. Both outcomes are
        // valid depending on when this runs — assert consistency, not a fixed result.
        bool open = cal.isMarketOpen();
        if (open) {
            _swap();
        } else {
            vm.expectRevert();
            _swap();
        }
    }
}
