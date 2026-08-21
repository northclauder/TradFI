// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MarketCalendar} from "../src/MarketCalendar.sol";

contract MarketCalendarDstTest is Test {
    MarketCalendar cal;

    function setUp() public {
        cal = new MarketCalendar(address(this), new MarketCalendar.CalendarDate[](0));
    }

    // DST 2026 starts Sun Mar 8 02:00 EST = 07:00 UTC (ts 1772953200)
    function test_dstStart2026() public view {
        assertEq(cal.etOffsetSeconds(1772953199), 5 hours); // 06:59:59 UTC
        assertEq(cal.etOffsetSeconds(1772953200), 4 hours); // 07:00:00 UTC
    }

    // DST 2026 ends Sun Nov 1 02:00 EDT = 06:00 UTC (ts 1793512800)
    function test_dstEnd2026() public view {
        assertEq(cal.etOffsetSeconds(1793512799), 4 hours); // 05:59:59 UTC
        assertEq(cal.etOffsetSeconds(1793512800), 5 hours); // 06:00:00 UTC
    }

    // 2027: starts Sun Mar 14 07:00 UTC (1805007600), ends Sun Nov 7 06:00 UTC (1825567200)
    function test_dst2027Boundaries() public view {
        assertEq(cal.etOffsetSeconds(1805007599), 5 hours);
        assertEq(cal.etOffsetSeconds(1805007600), 4 hours);
        assertEq(cal.etOffsetSeconds(1825567199), 4 hours);
        assertEq(cal.etOffsetSeconds(1825567200), 5 hours);
    }

    function test_januaryIsEst_julyIsEdt() public view {
        assertEq(cal.etOffsetSeconds(1767225600), 5 hours); // 2026-01-01 00:00 UTC
        assertEq(cal.etOffsetSeconds(1783036800), 4 hours); // 2026-07-03 00:00 UTC
    }
}
