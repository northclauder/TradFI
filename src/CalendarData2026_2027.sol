// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {MarketCalendar} from "./MarketCalendar.sol";

/// @notice Official NYSE holiday and early-close calendar for 2026 and 2027,
///         per the NYSE Group announcement (verified 2026-08-21). Used to seed
///         MarketCalendar at deploy and in tests.
library CalendarData2026_2027 {
    function entries() internal pure returns (MarketCalendar.CalendarDate[] memory e) {
        MarketCalendar.DayStatus H = MarketCalendar.DayStatus.Holiday;
        MarketCalendar.DayStatus HD = MarketCalendar.DayStatus.HalfDay;
        e = new MarketCalendar.CalendarDate[](23);
        // 2026 full closures
        e[0] = MarketCalendar.CalendarDate(2026, 1, 1, H); // New Year's Day (Thu)
        e[1] = MarketCalendar.CalendarDate(2026, 1, 19, H); // MLK Day
        e[2] = MarketCalendar.CalendarDate(2026, 2, 16, H); // Washington's Birthday
        e[3] = MarketCalendar.CalendarDate(2026, 4, 3, H); // Good Friday
        e[4] = MarketCalendar.CalendarDate(2026, 5, 25, H); // Memorial Day
        e[5] = MarketCalendar.CalendarDate(2026, 6, 19, H); // Juneteenth
        e[6] = MarketCalendar.CalendarDate(2026, 7, 3, H); // Independence Day (observed, Jul 4 = Sat)
        e[7] = MarketCalendar.CalendarDate(2026, 9, 7, H); // Labor Day
        e[8] = MarketCalendar.CalendarDate(2026, 11, 26, H); // Thanksgiving
        e[9] = MarketCalendar.CalendarDate(2026, 12, 25, H); // Christmas
        // 2026 early closes (13:00 ET)
        e[10] = MarketCalendar.CalendarDate(2026, 11, 27, HD); // day after Thanksgiving
        e[11] = MarketCalendar.CalendarDate(2026, 12, 24, HD); // Christmas Eve
        // 2027 full closures
        e[12] = MarketCalendar.CalendarDate(2027, 1, 1, H); // New Year's Day (Fri)
        e[13] = MarketCalendar.CalendarDate(2027, 1, 18, H); // MLK Day
        e[14] = MarketCalendar.CalendarDate(2027, 2, 15, H); // Washington's Birthday
        e[15] = MarketCalendar.CalendarDate(2027, 3, 26, H); // Good Friday
        e[16] = MarketCalendar.CalendarDate(2027, 5, 31, H); // Memorial Day
        e[17] = MarketCalendar.CalendarDate(2027, 6, 18, H); // Juneteenth (observed, Jun 19 = Sat)
        e[18] = MarketCalendar.CalendarDate(2027, 7, 5, H); // Independence Day (observed, Jul 4 = Sun)
        e[19] = MarketCalendar.CalendarDate(2027, 9, 6, H); // Labor Day
        e[20] = MarketCalendar.CalendarDate(2027, 11, 25, H); // Thanksgiving
        e[21] = MarketCalendar.CalendarDate(2027, 12, 24, H); // Christmas (observed, Dec 25 = Sat)
        // 2027 early closes (13:00 ET)
        e[22] = MarketCalendar.CalendarDate(2027, 11, 26, HD); // day after Thanksgiving
    }
}
