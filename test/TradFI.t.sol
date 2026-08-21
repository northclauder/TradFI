// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {TradFI} from "../src/TradFI.sol";

contract TradFITest is Test {
    TradFI token;

    function setUp() public {
        token = new TradFI();
    }

    function test_metadata() public view {
        assertEq(token.name(), "TradFI");
        assertEq(token.symbol(), "TRADFI");
        assertEq(token.decimals(), 18);
    }

    function test_supplyMintedToDeployer() public view {
        assertEq(token.totalSupply(), 1_792_000_000e18);
        assertEq(token.balanceOf(address(this)), 1_792_000_000e18);
    }

    function test_transferAlwaysWorks() public {
        token.transfer(address(0xBEEF), 1e18);
        assertEq(token.balanceOf(address(0xBEEF)), 1e18);
    }

    function test_transferFromWithApproval() public {
        token.approve(address(0xCAFE), 5e18);
        vm.prank(address(0xCAFE));
        token.transferFrom(address(this), address(0xBEEF), 5e18);
        assertEq(token.balanceOf(address(0xBEEF)), 5e18);
    }
}
