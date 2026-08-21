// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MarketCalendar} from "../src/MarketCalendar.sol";
import {EtTime} from "./utils/EtTime.sol";

contract MarketCalendarHoursTest is Test {
    MarketCalendar cal;

    function setUp() public {
        MarketCalendar.CalendarDate[] memory seed = new MarketCalendar.CalendarDate[](2);
        seed[0] = MarketCalendar.CalendarDate(2026, 11, 26, MarketCalendar.DayStatus.Holiday); // Thanksgiving
        seed[1] = MarketCalendar.CalendarDate(2026, 11, 27, MarketCalendar.DayStatus.HalfDay); // day after
        cal = new MarketCalendar(address(this), seed);
    }

    function _ts(uint256 y, uint256 mo, uint256 d, uint256 h, uint256 mi, uint256 s)
        internal
        view
        returns (uint256)
    {
        return EtTime.ts(cal, y, mo, d, h, mi, s);
    }

    function test_openCloseBoundaries_regularDay() public view {
        // Fri 2026-08-21 (EDT)
        assertFalse(cal.isMarketOpenAt(_ts(2026, 8, 21, 9, 29, 59)));
        assertTrue(cal.isMarketOpenAt(_ts(2026, 8, 21, 9, 30, 0)));
        assertTrue(cal.isMarketOpenAt(_ts(2026, 8, 21, 15, 59, 59)));
        assertFalse(cal.isMarketOpenAt(_ts(2026, 8, 21, 16, 0, 0)));
    }

    function test_boundaries_winterDay() public view {
        // Wed 2026-01-14 (EST)
        assertFalse(cal.isMarketOpenAt(_ts(2026, 1, 14, 9, 29, 59)));
        assertTrue(cal.isMarketOpenAt(_ts(2026, 1, 14, 9, 30, 0)));
        assertTrue(cal.isMarketOpenAt(_ts(2026, 1, 14, 15, 59, 59)));
        assertFalse(cal.isMarketOpenAt(_ts(2026, 1, 14, 16, 0, 0)));
    }

    function test_weekendClosed() public view {
        assertFalse(cal.isMarketOpenAt(_ts(2026, 8, 22, 12, 0, 0))); // Saturday
        assertFalse(cal.isMarketOpenAt(_ts(2026, 8, 23, 12, 0, 0))); // Sunday
    }

    function test_holidayClosed() public view {
        assertFalse(cal.isMarketOpenAt(_ts(2026, 11, 26, 12, 0, 0)));
    }

    function test_halfDayClosesAt1300() public view {
        assertTrue(cal.isMarketOpenAt(_ts(2026, 11, 27, 9, 30, 0)));
        assertTrue(cal.isMarketOpenAt(_ts(2026, 11, 27, 12, 59, 59)));
        assertFalse(cal.isMarketOpenAt(_ts(2026, 11, 27, 13, 0, 0)));
    }

    function test_tradingDaysAroundDstTransitions() public view {
        // Mon 2026-03-09, first trading day in EDT: 9:30 ET = 13:30 UTC
        assertTrue(cal.isMarketOpenAt(_ts(2026, 3, 9, 9, 30, 0)));
        assertFalse(cal.isMarketOpenAt(_ts(2026, 3, 9, 9, 29, 59)));
        // Fri 2026-03-06, last full trading day in EST: 9:30 ET = 14:30 UTC
        assertTrue(cal.isMarketOpenAt(_ts(2026, 3, 6, 9, 30, 0)));
        // Mon 2026-11-02, first trading day back in EST
        assertTrue(cal.isMarketOpenAt(_ts(2026, 11, 2, 9, 30, 0)));
        assertFalse(cal.isMarketOpenAt(_ts(2026, 11, 2, 9, 29, 59)));
    }

    function test_isMarketOpen_usesBlockTimestamp() public {
        vm.warp(_ts(2026, 8, 21, 12, 0, 0));
        assertTrue(cal.isMarketOpen());
        vm.warp(_ts(2026, 8, 21, 17, 0, 0));
        assertFalse(cal.isMarketOpen());
    }
}
