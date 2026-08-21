// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {MarketCalendar} from "../src/MarketCalendar.sol";

contract MarketCalendarAdminTest is Test {
    MarketCalendar cal;

    function setUp() public {
        vm.warp(1787690000); // 2026-08-25, i.e. "current year" is 2026
        cal = new MarketCalendar(address(this), new MarketCalendar.CalendarDate[](0));
    }

    function test_setFutureYearWorks() public {
        MarketCalendar.CalendarDate[] memory e = new MarketCalendar.CalendarDate[](1);
        e[0] = MarketCalendar.CalendarDate(2028, 12, 25, MarketCalendar.DayStatus.Holiday);
        cal.setCalendar(2028, e);
        assertEq(uint8(cal.dayStatus(20281225)), uint8(MarketCalendar.DayStatus.Holiday));
        assertEq(cal.lastCalendarYear(), 2028);
    }

    function test_setCurrentYearReverts() public {
        MarketCalendar.CalendarDate[] memory e = new MarketCalendar.CalendarDate[](1);
        e[0] = MarketCalendar.CalendarDate(2026, 12, 25, MarketCalendar.DayStatus.Holiday);
        vm.expectRevert(MarketCalendar.CalendarYearNotFuture.selector);
        cal.setCalendar(2026, e);
    }

    function test_setPastYearReverts() public {
        vm.expectRevert(MarketCalendar.CalendarYearNotFuture.selector);
        cal.setCalendar(2025, new MarketCalendar.CalendarDate[](0));
    }

    function test_entryYearMustMatchTargetYear() public {
        MarketCalendar.CalendarDate[] memory e = new MarketCalendar.CalendarDate[](1);
        e[0] = MarketCalendar.CalendarDate(2029, 1, 1, MarketCalendar.DayStatus.Holiday);
        vm.expectRevert(MarketCalendar.InvalidDate.selector);
        cal.setCalendar(2028, e);
    }

    function test_invalidDateReverts() public {
        MarketCalendar.CalendarDate[] memory e = new MarketCalendar.CalendarDate[](1);
        e[0] = MarketCalendar.CalendarDate(2028, 2, 30, MarketCalendar.DayStatus.Holiday);
        vm.expectRevert(MarketCalendar.InvalidDate.selector);
        cal.setCalendar(2028, e);
    }

    function test_constructorRejectsInvalidDate() public {
        MarketCalendar.CalendarDate[] memory e = new MarketCalendar.CalendarDate[](1);
        e[0] = MarketCalendar.CalendarDate(2026, 13, 1, MarketCalendar.DayStatus.Holiday);
        vm.expectRevert(MarketCalendar.InvalidDate.selector);
        new MarketCalendar(address(this), e);
    }

    function test_onlyOwner() public {
        vm.prank(address(0xBEEF));
        vm.expectRevert();
        cal.setCalendar(2028, new MarketCalendar.CalendarDate[](0));
    }

    function test_yearBoundaryUsesEasternTime() public {
        // 2027-01-01 03:00 UTC is still 2026-12-31 22:00 ET -> current year 2026,
        // so setting 2027 must still be allowed.
        vm.warp(1798772400); // 2027-01-01 03:00:00 UTC
        MarketCalendar.CalendarDate[] memory e = new MarketCalendar.CalendarDate[](1);
        e[0] = MarketCalendar.CalendarDate(2027, 12, 24, MarketCalendar.DayStatus.Holiday);
        cal.setCalendar(2027, e);
        assertEq(uint8(cal.dayStatus(20271224)), uint8(MarketCalendar.DayStatus.Holiday));
    }
}
