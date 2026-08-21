// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MarketCalendar} from "../src/MarketCalendar.sol";
import {CalendarData2026_2027} from "../src/CalendarData2026_2027.sol";
import {DateTimeLib} from "../src/lib/DateTimeLib.sol";
import {EtTime} from "./utils/EtTime.sol";

contract MarketCalendarAcceptanceTest is Test {
    MarketCalendar cal;

    // Independently verified DST boundaries (UTC)
    uint256 constant DST_START_2026 = 1772953200; // 2026-03-08 07:00
    uint256 constant DST_END_2026 = 1793512800; // 2026-11-01 06:00
    uint256 constant DST_START_2027 = 1805007600; // 2027-03-14 07:00
    uint256 constant DST_END_2027 = 1825567200; // 2027-11-07 06:00

    uint256[] holidayEpochDays;
    uint256[] halfDayEpochDays;

    function setUp() public {
        cal = new MarketCalendar(address(this), CalendarData2026_2027.entries());
        MarketCalendar.CalendarDate[] memory e = CalendarData2026_2027.entries();
        for (uint256 i = 0; i < e.length; i++) {
            uint256 ed = DateTimeLib.dateToEpochDay(e[i].year, e[i].month, e[i].day);
            if (e[i].status == MarketCalendar.DayStatus.Holiday) holidayEpochDays.push(ed);
            else halfDayEpochDays.push(ed);
        }
    }

    function _ts(uint256 y, uint256 mo, uint256 d, uint256 h, uint256 mi, uint256 s)
        internal
        view
        returns (uint256)
    {
        return EtTime.ts(cal, y, mo, d, h, mi, s);
    }

    // === Reference model: independent composition using verified DST constants ===

    function _refOffset(uint256 ts) internal pure returns (uint256) {
        if (ts >= DST_START_2026 && ts < DST_END_2026) return 4 hours;
        if (ts >= DST_START_2027 && ts < DST_END_2027) return 4 hours;
        return 5 hours;
    }

    function _refIsOpen(uint256 ts) internal view returns (bool) {
        uint256 et = ts - _refOffset(ts);
        uint256 epochDay = et / 86400;
        uint256 wd = (epochDay + 4) % 7;
        if (wd == 0 || wd == 6) return false;
        for (uint256 i = 0; i < holidayEpochDays.length; i++) {
            if (holidayEpochDays[i] == epochDay) return false;
        }
        uint256 close = 16 hours;
        for (uint256 i = 0; i < halfDayEpochDays.length; i++) {
            if (halfDayEpochDays[i] == epochDay) close = 13 hours;
        }
        uint256 sec = et % 86400;
        return sec >= 9 hours + 30 minutes && sec < close;
    }

    function test_fuzz_matchesReferenceModel(uint256 ts) public view {
        ts = bound(ts, 1767225600, 1830297599); // 2026-01-01 .. 2027-12-31 (UTC)
        assertEq(cal.isMarketOpenAt(ts), _refIsOpen(ts));
    }

    // === Exhaustive day sweep for 2026 ===

    function test_all2026Days_noonEtStatusAndCount() public view {
        uint256 start = DateTimeLib.dateToEpochDay(2026, 1, 1);
        uint256 tradingDays;
        for (uint256 ed = start; ed < start + 365; ed++) {
            (uint256 y, uint256 m, uint256 d) = DateTimeLib.epochDayToDate(ed);
            uint256 noon = _ts(y, m, d, 12, 0, 0);
            bool open = cal.isMarketOpenAt(noon);
            assertEq(open, _refIsOpen(noon));
            if (open) tradingDays++;
        }
        // 2026: 261 weekdays minus 10 holidays = 251 trading days
        assertEq(tradingDays, 251);
    }

    function test_all2026Holidays_closedAllDay() public view {
        uint256[10] memory months = [uint256(1), 1, 2, 4, 5, 6, 7, 9, 11, 12];
        uint256[10] memory days_ = [uint256(1), 19, 16, 3, 25, 19, 3, 7, 26, 25];
        for (uint256 i = 0; i < 10; i++) {
            assertFalse(cal.isMarketOpenAt(_ts(2026, months[i], days_[i], 12, 0, 0)));
            assertFalse(cal.isMarketOpenAt(_ts(2026, months[i], days_[i], 9, 30, 0)));
        }
    }

    function test_halfDays2026() public view {
        assertTrue(cal.isMarketOpenAt(_ts(2026, 11, 27, 12, 59, 59)));
        assertFalse(cal.isMarketOpenAt(_ts(2026, 11, 27, 13, 0, 0)));
        assertTrue(cal.isMarketOpenAt(_ts(2026, 12, 24, 12, 59, 59)));
        assertFalse(cal.isMarketOpenAt(_ts(2026, 12, 24, 13, 0, 0)));
    }

    function test_2027ObservedHolidays() public view {
        assertFalse(cal.isMarketOpenAt(_ts(2027, 6, 18, 12, 0, 0))); // Juneteenth observed
        assertFalse(cal.isMarketOpenAt(_ts(2027, 7, 5, 12, 0, 0))); // July 4th observed
        assertFalse(cal.isMarketOpenAt(_ts(2027, 12, 24, 12, 0, 0))); // Christmas observed
        // Dec 23 2027 (Thu) is a normal full trading day
        assertTrue(cal.isMarketOpenAt(_ts(2027, 12, 23, 15, 59, 59)));
    }

    function test_calendarFallback_beyondLastYearWeekdaysOpen() public view {
        // 2029-01-03 is a Wednesday with no calendar data -> open (fallback by design)
        assertTrue(cal.isMarketOpenAt(_ts(2029, 1, 3, 12, 0, 0)));
        // weekends still closed
        assertFalse(cal.isMarketOpenAt(_ts(2029, 1, 6, 12, 0, 0))); // Saturday
        assertEq(cal.lastCalendarYear(), 2027);
    }
}
