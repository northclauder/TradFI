// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Minimal date math based on Howard Hinnant's civil-date algorithms.
///         Valid for the range this project cares about (1970 to ~2170).
library DateTimeLib {
    function epochDayToDate(uint256 epochDay)
        internal
        pure
        returns (uint256 year, uint256 month, uint256 day)
    {
        unchecked {
            uint256 z = epochDay + 719468;
            uint256 era = z / 146097;
            uint256 doe = z - era * 146097;
            uint256 yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
            uint256 doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
            uint256 mp = (5 * doy + 2) / 153;
            day = doy - (153 * mp + 2) / 5 + 1;
            month = mp < 10 ? mp + 3 : mp - 9;
            year = yoe + era * 400 + (month <= 2 ? 1 : 0);
        }
    }

    function dateToEpochDay(uint256 year, uint256 month, uint256 day)
        internal
        pure
        returns (uint256 epochDay)
    {
        unchecked {
            uint256 y = year - (month <= 2 ? 1 : 0);
            uint256 era = y / 400;
            uint256 yoe = y - era * 400;
            uint256 mp = month > 2 ? month - 3 : month + 9;
            uint256 doy = (153 * mp + 2) / 5 + day - 1;
            uint256 doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
            epochDay = era * 146097 + doe - 719468;
        }
    }

    /// @return wd 0=Sunday .. 6=Saturday
    function weekday(uint256 epochDay) internal pure returns (uint256 wd) {
        unchecked {
            wd = (epochDay + 4) % 7;
        }
    }

    /// @notice Day-of-month of the nth Sunday of (year, month). n is 1-based.
    function nthSundayOfMonth(uint256 year, uint256 month, uint256 n)
        internal
        pure
        returns (uint256)
    {
        uint256 firstWd = weekday(dateToEpochDay(year, month, 1));
        uint256 firstSunday = 1 + ((7 - firstWd) % 7);
        return firstSunday + (n - 1) * 7;
    }
}
