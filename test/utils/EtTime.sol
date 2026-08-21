// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {DateTimeLib} from "../../src/lib/DateTimeLib.sol";
import {MarketCalendar} from "../../src/MarketCalendar.sol";

/// @notice Test helper: build a UTC timestamp from an ET wall-clock time.
///         Correct for all times that do not straddle the 02:00 DST switch,
///         which market hours never do.
library EtTime {
    function ts(
        MarketCalendar cal,
        uint256 y,
        uint256 mo,
        uint256 d,
        uint256 h,
        uint256 mi,
        uint256 s
    ) internal pure returns (uint256) {
        uint256 etSeconds = DateTimeLib.dateToEpochDay(y, mo, d) * 86400 + h * 3600 + mi * 60 + s;
        // guess with EST, then correct with the offset at the guessed instant
        uint256 guess = etSeconds + 5 hours;
        return etSeconds + cal.etOffsetSeconds(guess);
    }
}
