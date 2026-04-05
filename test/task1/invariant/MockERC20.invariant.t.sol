// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {StdInvariant} from "forge-std/StdInvariant.sol";
import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../../src/task1/MockERC20.sol";
import {MockERC20Handler} from "./MockERC20Handler.t.sol";

contract MockERC20InvariantTest is StdInvariant, Test {
    MockERC20 internal token;
    MockERC20Handler internal handler;

    function setUp() public {
        token = new MockERC20("Assignment Token", "ATK");
        handler = new MockERC20Handler(token);

        targetContract(address(handler));
    }

    function invariant_TotalSupplyNeverChanges() public view {
        assertEq(token.totalSupply(), 1_750 ether);
    }

    function invariant_NoActorCanHoldMoreThanTotalSupply() public view {
        uint256 actorCount = handler.actorCount();

        for (uint256 i = 0; i < actorCount; ++i) {
            assertLe(token.balanceOf(handler.actorAt(i)), token.totalSupply());
        }
    }

    function invariant_SumOfTrackedBalancesMatchesTotalSupply() public view {
        uint256 actorCount = handler.actorCount();
        uint256 trackedSupply;

        for (uint256 i = 0; i < actorCount; ++i) {
            trackedSupply += token.balanceOf(handler.actorAt(i));
        }

        assertEq(trackedSupply, token.totalSupply());
    }
}
