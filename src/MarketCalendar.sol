// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {DateTimeLib} from "./lib/DateTimeLib.sol";

/// @notice On-chain NYSE trading-hours calendar in US Eastern Time.
///         Regular hours 09:30-16:00 ET Mon-Fri, half days close 13:00 ET.
///         DST is computed deterministically (2nd Sunday of March 02:00 local
///         to 1st Sunday of November 02:00 local). Holidays and half days are
///         stored per date; the owner can only set calendar data for FUTURE
///         years, so the market can never be manipulated same-day. Dates with
///         no entry are regular trading days, so if the calendar is never
///         updated again the market simply runs holiday-free.
contract MarketCalendar is Ownable {
    enum DayStatus {
        Normal,
        Holiday,
        HalfDay
    }

    struct CalendarDate {
        uint16 year;
        uint8 month;
        uint8 day;
        DayStatus status;
    }

    /// @notice key = year * 10000 + month * 100 + day (ET civil date)
    mapping(uint256 => DayStatus) public dayStatus;

    /// @notice Highest year with calendar data, for transparency/frontends.
    uint256 public lastCalendarYear;

    error CalendarYearNotFuture();
    error InvalidDate();

    constructor(address owner_, CalendarDate[] memory seed) Ownable(owner_) {
        _setEntries(seed);
    }

    /// @notice Seconds to subtract from UTC to get ET (5h EST / 4h EDT).
    function etOffsetSeconds(uint256 timestamp) public pure returns (uint256) {
        (uint256 y,,) = DateTimeLib.epochDayToDate(timestamp / 86400);
        // DST window in UTC: 2nd Sunday of March 07:00 (02:00 EST)
        // until 1st Sunday of November 06:00 (02:00 EDT).
        uint256 dstStart =
            DateTimeLib.dateToEpochDay(y, 3, DateTimeLib.nthSundayOfMonth(y, 3, 2)) * 86400 + 7 hours;
        uint256 dstEnd =
            DateTimeLib.dateToEpochDay(y, 11, DateTimeLib.nthSundayOfMonth(y, 11, 1)) * 86400 + 6 hours;
        return (timestamp >= dstStart && timestamp < dstEnd) ? 4 hours : 5 hours;
    }

    function _setEntries(CalendarDate[] memory entries) internal {
        for (uint256 i = 0; i < entries.length; i++) {
            CalendarDate memory e = entries[i];
            uint256 ed = DateTimeLib.dateToEpochDay(e.year, e.month, e.day);
            (uint256 y2, uint256 m2, uint256 d2) = DateTimeLib.epochDayToDate(ed);
            if (y2 != e.year || m2 != e.month || d2 != e.day) revert InvalidDate();
            dayStatus[uint256(e.year) * 10000 + uint256(e.month) * 100 + e.day] = e.status;
            if (e.year > lastCalendarYear) lastCalendarYear = e.year;
        }
    }
}
