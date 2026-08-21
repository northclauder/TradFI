// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice TradFI — the memecoin that keeps banker's hours. The token itself is
///         a plain ERC-20; trading hours are enforced by the pool hook, not here.
///         Supply: 1,792,000,000 (the NYSE was founded in 1792).
contract TradFI is ERC20 {
    constructor() ERC20("TradFI", "TRADFI") {
        _mint(msg.sender, 1_792_000_000e18);
    }
}
