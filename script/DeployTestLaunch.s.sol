// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";

import {DeployLib} from "./DeployLib.sol";
import {TestWindowsCalendar} from "../src/test-only/TestWindowsCalendar.sol";

/// @notice TESTNET-ONLY rehearsal launch with a compressed schedule: the pool
///         is open 10 minutes, closed 10 minutes, alternating forever. Uses the
///         exact same hook/token/lock code and deploy path as the real launch —
///         only the calendar is swapped. Refuses to run on mainnet.
contract DeployTestLaunchScript is Script {
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

    function run() external {
        require(block.chainid != 4663, "TEST-ONLY: refusing to run on mainnet");

        vm.startBroadcast();
        TestWindowsCalendar testCal = new TestWindowsCalendar();

        DeployLib.Result memory r = DeployLib.run(
            DeployLib.Params({
                owner: vm.envOr("OWNER", msg.sender),
                poolManager: IPoolManager(vm.envAddress("POOL_MANAGER")),
                positionManager: IPositionManager(payable(vm.envAddress("POSITION_MANAGER"))),
                permit2: IAllowanceTransfer(vm.envAddress("PERMIT2")),
                weth: IERC20(vm.envAddress("WETH")),
                wethAmount: vm.envUint("WETH_AMOUNT"),
                sqrtPriceX96: 0,
                create2Deployer: CREATE2_DEPLOYER,
                calendarOverride: address(testCal)
            })
        );
        DeployLib.burnDust(r.token, msg.sender);
        vm.stopBroadcast();

        console2.log("TEST token:       ", address(r.token));
        console2.log("TestWindowsCal:   ", address(testCal));
        console2.log("NYSEHoursHook:    ", address(r.hook));
        console2.log("LPLock:           ", address(r.lock));
        console2.log("Position tokenId: ", r.tokenId);
        console2.log("Window open now?  ", testCal.isMarketOpen());
        console2.log("Next open:        ", testCal.nextOpen(block.timestamp));
    }
}
