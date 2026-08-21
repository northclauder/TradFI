// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {DateTimeLib} from "../src/lib/DateTimeLib.sol";

contract DateTimeLibTest is Test {
    function test_epochDayToDate_knownDates() public pure {
        (uint256 y, uint256 m, uint256 d) = DateTimeLib.epochDayToDate(0);
        assertEq(y, 1970);
        assertEq(m, 1);
        assertEq(d, 1);
        // 2026-08-21 = epoch day 20686
        (y, m, d) = DateTimeLib.epochDayToDate(20686);
        assertEq(y, 2026);
        assertEq(m, 8);
        assertEq(d, 21);
        // leap day 2024-02-29 = epoch day 19782
        (y, m, d) = DateTimeLib.epochDayToDate(19782);
        assertEq(y, 2024);
        assertEq(m, 2);
        assertEq(d, 29);
    }

    function test_dateToEpochDay_knownDates() public pure {
        assertEq(DateTimeLib.dateToEpochDay(1970, 1, 1), 0);
        assertEq(DateTimeLib.dateToEpochDay(2026, 8, 21), 20686);
        assertEq(DateTimeLib.dateToEpochDay(2024, 2, 29), 19782);
    }

    function test_roundtrip_fuzz(uint256 epochDay) public pure {
        epochDay = epochDay % 73048; // 1970..~2170
        (uint256 y, uint256 m, uint256 d) = DateTimeLib.epochDayToDate(epochDay);
        assertEq(DateTimeLib.dateToEpochDay(y, m, d), epochDay);
        assertTrue(m >= 1 && m <= 12);
        assertTrue(d >= 1 && d <= 31);
    }

    function test_weekday() public pure {
        assertEq(DateTimeLib.weekday(0), 4); // 1970-01-01 Thursday (0=Sunday)
        assertEq(DateTimeLib.weekday(20686), 5); // 2026-08-21 Friday
        assertEq(DateTimeLib.weekday(20688), 0); // 2026-08-23 Sunday
    }

    function test_nthSunday() public pure {
        // DST anchors: second Sunday of March / first Sunday of November
        assertEq(DateTimeLib.nthSundayOfMonth(2026, 3, 2), 8); // 2026-03-08
        assertEq(DateTimeLib.nthSundayOfMonth(2026, 11, 1), 1); // 2026-11-01
        assertEq(DateTimeLib.nthSundayOfMonth(2027, 3, 2), 14); // 2027-03-14
        assertEq(DateTimeLib.nthSundayOfMonth(2027, 11, 1), 7); // 2027-11-07
        assertEq(DateTimeLib.nthSundayOfMonth(2028, 3, 2), 12); // 2028-03-12
        assertEq(DateTimeLib.nthSundayOfMonth(2028, 11, 1), 5); // 2028-11-05
    }
}
