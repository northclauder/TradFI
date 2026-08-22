// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice TEST-ONLY calendar with compressed trading windows: open for 10
///         minutes, closed for 10 minutes, forever alternating. ABI-compatible
///         with the functions NYSEHoursHook calls on MarketCalendar, so a
///         rehearsal pool can demonstrate the open/close mechanic in minutes
///         instead of waiting for NYSE hours. NEVER deploy to mainnet.
contract TestWindowsCalendar {
    uint256 public constant WINDOW = 600; // 10 minutes

    function isMarketOpen() external view returns (bool) {
        return isMarketOpenAt(block.timestamp);
    }

    function isMarketOpenAt(uint256 timestamp) public pure returns (bool) {
        return (timestamp / WINDOW) % 2 == 0;
    }

    function nextOpen(uint256 timestamp) public pure returns (uint256) {
        if (isMarketOpenAt(timestamp)) return timestamp;
        return ((timestamp / WINDOW) + 1) * WINDOW;
    }
}
