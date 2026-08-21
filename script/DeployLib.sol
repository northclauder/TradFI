// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {TickMath} from "v4-core/src/libraries/TickMath.sol";
import {FullMath} from "v4-core/src/libraries/FullMath.sol";
import {Math} from "@openzeppelin/contracts/utils/math/Math.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {LiquidityAmounts} from "v4-periphery/src/libraries/LiquidityAmounts.sol";
import {HookMiner} from "v4-periphery/test/shared/HookMiner.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {TradFI} from "../src/TradFI.sol";
import {MarketCalendar} from "../src/MarketCalendar.sol";
import {CalendarData2026_2027} from "../src/CalendarData2026_2027.sol";
import {NYSEHoursHook} from "../src/NYSEHoursHook.sol";
import {LPLock} from "../src/LPLock.sol";

/// @notice The full TradFI launch sequence, shared between the deploy script and
///         the local integration test so the exact code path that ships is the
///         one that is tested. Runs as the caller (script EOA under broadcast,
///         or the test contract):
///         1. deploy MarketCalendar seeded with the official NYSE 2026-2027 data
///         2. mine + CREATE2-deploy NYSEHoursHook
///         3. deploy TradFI (full supply to caller) and LPLock
///         4. init the 1% TRADFI/WETH pool and mint the full-range position
///            straight to LPLock (unlocked liquidity never exists)
///         5. register the lock, burn any leftover dust to 0xdead
library DeployLib {
    uint24 internal constant FEE = 10000; // 1%
    int24 internal constant TICK_SPACING = 200;
    int24 internal constant FULL_RANGE_LOWER = -887200; // MIN_TICK aligned to 200
    int24 internal constant FULL_RANGE_UPPER = 887200;

    struct Params {
        address owner; // calendar admin + fee collector (LPLock owner)
        IPoolManager poolManager;
        IPositionManager positionManager;
        IAllowanceTransfer permit2;
        IERC20 weth;
        uint256 wethAmount;
        uint160 sqrtPriceX96; // initial price for the sorted pair; 0 = derive from amounts
        address create2Deployer; // who executes CREATE2 for the hook (differs script vs test)
    }

    struct Result {
        TradFI token;
        MarketCalendar calendar;
        NYSEHoursHook hook;
        LPLock lock;
        PoolKey key;
        uint256 tokenId;
    }

    error HookAddressMismatch();
    error TooMuchDust();

    function run(Params memory p) internal returns (Result memory r) {
        // 1. calendar
        r.calendar = new MarketCalendar(p.owner, CalendarData2026_2027.entries());

        // 2. hook at a mined CREATE2 address with exactly BEFORE_SWAP_FLAG
        (address hookAddr, bytes32 salt) = HookMiner.find(
            p.create2Deployer,
            uint160(Hooks.BEFORE_SWAP_FLAG),
            type(NYSEHoursHook).creationCode,
            abi.encode(p.poolManager, r.calendar)
        );
        r.hook = new NYSEHoursHook{salt: salt}(p.poolManager, r.calendar);
        if (address(r.hook) != hookAddr) revert HookAddressMismatch();

        // 3. token + lock
        r.token = new TradFI();
        r.lock = new LPLock(p.owner, p.positionManager);

        // 4. pool + full-range position minted directly to the lock
        uint256 tokenAmount = r.token.totalSupply();
        bool tokenIs0 = address(r.token) < address(p.weth);
        r.key = PoolKey({
            currency0: Currency.wrap(tokenIs0 ? address(r.token) : address(p.weth)),
            currency1: Currency.wrap(tokenIs0 ? address(p.weth) : address(r.token)),
            fee: FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(r.hook))
        });
        if (p.sqrtPriceX96 == 0) {
            p.sqrtPriceX96 = initialSqrtPriceX96(
                tokenIs0 ? tokenAmount : p.wethAmount,
                tokenIs0 ? p.wethAmount : tokenAmount
            );
        }
        initPoolAndApprovals(r, p);

        uint128 liquidity = LiquidityAmounts.getLiquidityForAmounts(
            p.sqrtPriceX96,
            TickMath.getSqrtPriceAtTick(FULL_RANGE_LOWER),
            TickMath.getSqrtPriceAtTick(FULL_RANGE_UPPER),
            tokenIs0 ? tokenAmount : p.wethAmount,
            tokenIs0 ? p.wethAmount : tokenAmount
        );

        r.tokenId = p.positionManager.nextTokenId();
        bytes memory actions =
            abi.encodePacked(uint8(Actions.MINT_POSITION), uint8(Actions.SETTLE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(
            r.key,
            FULL_RANGE_LOWER,
            FULL_RANGE_UPPER,
            uint256(liquidity),
            type(uint128).max,
            type(uint128).max,
            address(r.lock),
            bytes("")
        );
        params[1] = abi.encode(r.key.currency0, r.key.currency1);
        p.positionManager.modifyLiquidities(abi.encode(actions, params), block.timestamp);

        // 5. register the lock
        r.lock.lock(r.tokenId);
    }

    /// @notice The sqrtPriceX96 at which the pool holds exactly amount0:amount1,
    ///         i.e. sqrt(amount1/amount0) in Q96. Used when Params.sqrtPriceX96
    ///         is 0 so the initial price always matches the seeded amounts.
    function initialSqrtPriceX96(uint256 amount0, uint256 amount1)
        internal
        pure
        returns (uint160)
    {
        return uint160(Math.sqrt(FullMath.mulDiv(amount1, 1 << 192, amount0)));
    }

    /// @notice Burn whatever supply the mint left with the deployer (rounding
    ///         dust) so 100% of supply is provably out of team hands. Reverts if
    ///         the leftover exceeds 1% of supply — that means the initial price
    ///         and WETH amount were inconsistent and the launch should abort.
    function burnDust(TradFI token, address holder) internal {
        uint256 dust = token.balanceOf(holder);
        if (dust > token.totalSupply() / 100) revert TooMuchDust();
        if (dust > 0) {
            bool ok = token.transfer(0x000000000000000000000000000000000000dEaD, dust);
            require(ok, "dust burn failed");
        }
    }

    /// @dev init pool + approvals, split out to keep `run` readable
    function initPoolAndApprovals(Result memory r, Params memory p) internal {
        p.positionManager.initializePool(r.key, p.sqrtPriceX96);

        r.token.approve(address(p.permit2), type(uint256).max);
        p.weth.approve(address(p.permit2), type(uint256).max);
        p.permit2.approve(
            address(r.token), address(p.positionManager), type(uint160).max, type(uint48).max
        );
        p.permit2.approve(
            address(p.weth), address(p.positionManager), type(uint160).max, type(uint48).max
        );
    }
}
