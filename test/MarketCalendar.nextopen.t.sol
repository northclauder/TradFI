// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MarketCalendar} from "../src/MarketCalendar.sol";
import {EtTime} from "./utils/EtTime.sol";

contract MarketCalendarNextOpenTest is Test {
    MarketCalendar cal;

    function setUp() public {
        MarketCalendar.CalendarDate[] memory seed = new MarketCalendar.CalendarDate[](2);
        seed[0] = MarketCalendar.CalendarDate(2026, 11, 26, MarketCalendar.DayStatus.Holiday); // Thanksgiving
        seed[1] = MarketCalendar.CalendarDate(2026, 11, 27, MarketCalendar.DayStatus.HalfDay);
        cal = new MarketCalendar(address(this), seed);
    }

    function _ts(uint256 y, uint256 mo, uint256 d, uint256 h, uint256 mi, uint256 s)
        internal
        view
        returns (uint256)
    {
        return EtTime.ts(cal, y, mo, d, h, mi, s);
    }

    function test_beforeOpenSameDay() public view {
        assertEq(cal.nextOpen(_ts(2026, 8, 21, 8, 0, 0)), _ts(2026, 8, 21, 9, 30, 0));
    }

    function test_duringOpenReturnsNow() public view {
        uint256 t = _ts(2026, 8, 21, 12, 0, 0);
        assertEq(cal.nextOpen(t), t);
    }

    function test_afterCloseGoesToNextTradingDay() public view {
        // Fri 16:30 ET -> Mon 09:30 ET
        assertEq(cal.nextOpen(_ts(2026, 8, 21, 16, 30, 0)), _ts(2026, 8, 24, 9, 30, 0));
    }

    function test_saturdayGoesToMonday() public view {
        assertEq(cal.nextOpen(_ts(2026, 8, 22, 12, 0, 0)), _ts(2026, 8, 24, 9, 30, 0));
    }

    function test_skipsHoliday() public view {
        // Wed 2026-11-25 17:00 ET -> Fri 2026-11-27 09:30 (Thu is a holiday)
        assertEq(cal.nextOpen(_ts(2026, 11, 25, 17, 0, 0)), _ts(2026, 11, 27, 9, 30, 0));
    }

    function test_halfDayAfternoonGoesToNextTradingDay() public view {
        // Fri 2026-11-27 14:00 ET (half day, closed) -> Mon 2026-11-30 09:30
        assertEq(cal.nextOpen(_ts(2026, 11, 27, 14, 0, 0)), _ts(2026, 11, 30, 9, 30, 0));
    }

    function test_halfDayMorningBeforeOpenIsSameDay() public view {
        assertEq(cal.nextOpen(_ts(2026, 11, 27, 8, 0, 0)), _ts(2026, 11, 27, 9, 30, 0));
    }

    function test_acrossDstFallBack() public view {
        // Fri 2026-10-30 17:00 EDT -> Mon 2026-11-02 09:30 EST (offset changed over the weekend)
        assertEq(cal.nextOpen(_ts(2026, 10, 30, 17, 0, 0)), _ts(2026, 11, 2, 9, 30, 0));
    }

    function test_acrossDstSpringForward() public view {
        // Fri 2026-03-06 17:00 EST -> Mon 2026-03-09 09:30 EDT
        assertEq(cal.nextOpen(_ts(2026, 3, 6, 17, 0, 0)), _ts(2026, 3, 9, 9, 30, 0));
    }

    function test_fuzz_nextOpenIsOpenAndNothingEarlierIs(uint256 ts) public view {
        ts = bound(ts, 1767225600, 1830297600); // 2026..2028
        uint256 no = cal.nextOpen(ts);
        assertTrue(no != 0);
        assertTrue(no >= ts);
        assertTrue(cal.isMarketOpenAt(no));
        if (no > ts) {
            // the second before nextOpen must be closed
            assertFalse(cal.isMarketOpenAt(no - 1));
        }
    }
}
