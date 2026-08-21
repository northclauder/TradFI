// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC721Receiver} from "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import {IPositionManager} from "v4-periphery/src/interfaces/IPositionManager.sol";
import {PositionInfo} from "v4-periphery/src/libraries/PositionInfoLibrary.sol";
import {Actions} from "v4-periphery/src/libraries/Actions.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";

/// @notice Permanently holds the TRADFI/WETH LP position. There is no code path
///         that can transfer, decrease, or burn the position — the liquidity is
///         provably locked forever. The owner's only power is collecting the
///         accrued swap fees (a zero-liquidity decrease + take).
contract LPLock is Ownable, IERC721Receiver {
    IPositionManager public immutable positionManager;
    uint256 public tokenId;
    PoolKey public poolKey;

    error AlreadyLocked();
    error NotOwnedByLock();
    error NothingLocked();

    constructor(address owner_, IPositionManager positionManager_) Ownable(owner_) {
        positionManager = positionManager_;
    }

    /// @notice Register the locked position. Callable once, by anyone, after the
    ///         position NFT has been minted to this contract.
    function lock(uint256 tokenId_) external {
        if (tokenId != 0) revert AlreadyLocked();
        if (IERC721(address(positionManager)).ownerOf(tokenId_) != address(this)) {
            revert NotOwnedByLock();
        }
        (PoolKey memory key,) = positionManager.getPoolAndPositionInfo(tokenId_);
        tokenId = tokenId_;
        poolKey = key;
    }

    /// @notice Collect accrued swap fees to `to`. This is the only mutating
    ///         action this contract can ever perform on the position:
    ///         DECREASE_LIQUIDITY with liquidity = 0 (fees only) + TAKE_PAIR.
    function collectFees(address to) external onlyOwner {
        if (tokenId == 0) revert NothingLocked();
        bytes memory actions =
            abi.encodePacked(uint8(Actions.DECREASE_LIQUIDITY), uint8(Actions.TAKE_PAIR));
        bytes[] memory params = new bytes[](2);
        params[0] = abi.encode(tokenId, uint256(0), uint128(0), uint128(0), bytes(""));
        params[1] = abi.encode(poolKey.currency0, poolKey.currency1, to);
        positionManager.modifyLiquidities(abi.encode(actions, params), block.timestamp);
    }

    function onERC721Received(address, address, uint256, bytes calldata)
        external
        pure
        override
        returns (bytes4)
    {
        return IERC721Receiver.onERC721Received.selector;
    }
}

interface IERC721 {
    function ownerOf(uint256 tokenId) external view returns (address);
}
