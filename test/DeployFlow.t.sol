// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PosmTestSetup} from "v4-periphery/test/shared/PosmTestSetup.sol";
import {MockERC20} from "solmate/src/test/utils/mocks/MockERC20.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";

import {DeployLib} from "../script/DeployLib.sol";
import {MarketCalendar} from "../src/MarketCalendar.sol";
import {EtTime} from "./utils/EtTime.sol";

/// @notice Integration test of the exact launch sequence in DeployLib.
contract DeployFlowTest is PosmTestSetup {
    DeployLib.Result r;
    MockERC20 weth;

    uint256 constant WETH_AMOUNT = 1_792_000_000e18; // 1:1 price for the test

    function setUp() public {
        deployFreshManagerAndRouters();
        deployPosm(manager);

        weth = new MockERC20("Wrapped Ether", "WETH", 18);
        weth.mint(address(this), WETH_AMOUNT);

        r = DeployLib.run(
            DeployLib.Params({
                owner: address(this),
                poolManager: manager,
                positionManager: lpm,
                permit2: permit2,
                weth: IERC20(address(weth)),
                wethAmount: WETH_AMOUNT,
                sqrtPriceX96: SQRT_PRICE_1_1,
                create2Deployer: address(this)
            })
        );
        DeployLib.burnDust(r.token, address(this));

        // approvals for swap tests
        r.token.approve(address(swapRouter), type(uint256).max);
        weth.approve(address(swapRouter), type(uint256).max);
        weth.mint(address(this), 1000e18); // spending money for swaps
    }

    function _open() internal view returns (uint256) {
        return EtTime.ts(r.calendar, 2026, 8, 21, 12, 0, 0); // Fri noon ET
    }

    function _closed() internal view returns (uint256) {
        return EtTime.ts(r.calendar, 2026, 8, 22, 12, 0, 0); // Saturday
    }

    function test_lockOwnsFullRangePosition() public view {
        assertEq(IERC721(address(lpm)).ownerOf(r.tokenId), address(r.lock));
        assertGt(lpm.getPositionLiquidity(r.tokenId), 0);
        assertEq(r.lock.tokenId(), r.tokenId);
    }

    function test_deployerHoldsNoSupply() public view {
        assertEq(r.token.balanceOf(address(this)), 0);
        // everything is in the pool save for rounding dust burned to 0xdead
        uint256 dead = r.token.balanceOf(0x000000000000000000000000000000000000dEaD);
        assertLe(dead, r.token.totalSupply() / 100);
    }

    function test_swapWorksDuringHoursAndRevertsOutside() public {
        vm.warp(_open());
        bool wethIs0 = Currency.unwrap(r.key.currency0) == address(weth);
        // buy TRADFI with WETH
        swap(r.key, wethIs0, -1e18, ZERO_BYTES);
        assertGt(r.token.balanceOf(address(this)), 0);

        vm.warp(_closed());
        vm.expectRevert();
        swap(r.key, wethIs0, -1e18, ZERO_BYTES);
    }

    function test_feesCollectableByOwnerEvenWhenMarketClosed() public {
        vm.warp(_open());
        bool wethIs0 = Currency.unwrap(r.key.currency0) == address(weth);
        swap(r.key, wethIs0, -100e18, ZERO_BYTES);
        swap(r.key, !wethIs0, -50e18, ZERO_BYTES);

        vm.warp(_closed()); // fee collection is not gated by market hours
        address to = address(0xFEE);
        r.lock.collectFees(to);
        assertGt(
            weth.balanceOf(to) + r.token.balanceOf(to),
            0,
            "no fees collected"
        );
    }

    function test_hookAddressHasOnlyBeforeSwapFlag() public view {
        assertEq(uint160(address(r.hook)) & uint160((1 << 14) - 1), uint160(1 << 7));
    }

    function test_calendarOwnerIsConfiguredOwner() public view {
        assertEq(r.calendar.owner(), address(this));
        assertEq(r.lock.owner(), address(this));
        assertEq(r.calendar.lastCalendarYear(), 2027);
    }
}
