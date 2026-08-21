// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PosmTestSetup} from "v4-periphery/test/shared/PosmTestSetup.sol";
import {PositionConfig} from "v4-periphery/test/shared/PositionConfig.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IERC721} from "forge-std/interfaces/IERC721.sol";
import {LPLock} from "../src/LPLock.sol";

// Imported so forge produces artifacts for Deploy.sol's vm.getCode lookups.
import {PositionManager} from "v4-periphery/src/PositionManager.sol";
import {PositionDescriptor} from "v4-periphery/src/PositionDescriptor.sol";

contract LPLockTest is PosmTestSetup {
    LPLock lock;
    uint256 tokenId;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        (key,) = initPool(currency0, currency1, IHooks(address(0)), 3000, SQRT_PRICE_1_1);

        lock = new LPLock(address(this), lpm);

        PositionConfig memory config =
            PositionConfig({poolKey: key, tickLower: -600, tickUpper: 600});
        tokenId = lpm.nextTokenId();
        mint(config, 100e18, address(lock), ZERO_BYTES);
        lock.lock(tokenId);
    }

    function _generateFees() internal {
        swap(key, true, -10e18, ZERO_BYTES);
        swap(key, false, -10e18, ZERO_BYTES);
    }

    function test_lockRegisteredPosition() public view {
        assertEq(lock.tokenId(), tokenId);
        assertEq(IERC721(address(lpm)).ownerOf(tokenId), address(lock));
        (Currency c0,,,,) = lock.poolKey();
        assertEq(Currency.unwrap(c0), Currency.unwrap(key.currency0));
    }

    function test_collectFeesSendsFeesToRecipient() public {
        _generateFees();
        address to = address(0xFEE);
        lock.collectFees(to);
        uint256 got0 = IERC20(Currency.unwrap(key.currency0)).balanceOf(to);
        uint256 got1 = IERC20(Currency.unwrap(key.currency1)).balanceOf(to);
        assertGt(got0, 0);
        assertGt(got1, 0);
    }

    function test_collectFeesDoesNotReduceLiquidity() public {
        uint128 before = lpm.getPositionLiquidity(tokenId);
        _generateFees();
        lock.collectFees(address(0xFEE));
        assertEq(lpm.getPositionLiquidity(tokenId), before);
    }

    function test_collectFeesOnlyOwner() public {
        vm.prank(address(0xBAD));
        vm.expectRevert();
        lock.collectFees(address(0xBAD));
    }

    function test_positionCannotBeTransferredOut() public {
        vm.expectRevert();
        IERC721(address(lpm)).transferFrom(address(lock), address(0xBAD), tokenId);
    }

    function test_lockOnlyOnce() public {
        PositionConfig memory config =
            PositionConfig({poolKey: key, tickLower: -600, tickUpper: 600});
        uint256 second = lpm.nextTokenId();
        mint(config, 1e18, address(lock), ZERO_BYTES);
        vm.expectRevert(LPLock.AlreadyLocked.selector);
        lock.lock(second);
    }

    function test_lockRequiresOwnership() public {
        LPLock fresh = new LPLock(address(this), lpm);
        PositionConfig memory config =
            PositionConfig({poolKey: key, tickLower: -600, tickUpper: 600});
        uint256 mine = lpm.nextTokenId();
        mint(config, 1e18, address(this), ZERO_BYTES); // minted to us, not the lock
        vm.expectRevert(LPLock.NotOwnedByLock.selector);
        fresh.lock(mine);
    }

    function test_collectBeforeLockReverts() public {
        LPLock fresh = new LPLock(address(this), lpm);
        vm.expectRevert(LPLock.NothingLocked.selector);
        fresh.collectFees(address(this));
    }
}
