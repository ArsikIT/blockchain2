// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {MockERC20} from "../../../src/task1/MockERC20.sol";

contract MockERC20Handler is Test {
    MockERC20 internal immutable token;
    address[] internal actors;

    constructor(MockERC20 token_) {
        token = token_;

        actors.push(makeAddr("actor-alice"));
        actors.push(makeAddr("actor-bob"));
        actors.push(makeAddr("actor-carol"));

        token.mint(actors[0], 1_000 ether);
        token.mint(actors[1], 500 ether);
        token.mint(actors[2], 250 ether);
    }

    function transfer(uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        if (from == to) return;

        uint256 balance = token.balanceOf(from);
        if (balance == 0) return;

        amount = bound(amount, 0, balance);

        vm.prank(from);
        token.transfer(to, amount);
    }

    function approve(uint256 ownerSeed, uint256 spenderSeed, uint256 amount) external {
        address owner = actors[ownerSeed % actors.length];
        address spender = actors[spenderSeed % actors.length];

        vm.prank(owner);
        token.approve(spender, amount);
    }

    function transferFrom(uint256 spenderSeed, uint256 fromSeed, uint256 toSeed, uint256 amount) external {
        address spender = actors[spenderSeed % actors.length];
        address from = actors[fromSeed % actors.length];
        address to = actors[toSeed % actors.length];
        if (to == address(0)) return;

        uint256 allowed = token.allowance(from, spender);
        uint256 balance = token.balanceOf(from);
        uint256 maxTransfer = allowed < balance ? allowed : balance;

        if (maxTransfer == 0) return;

        amount = bound(amount, 0, maxTransfer);

        vm.prank(spender);
        token.transferFrom(from, to, amount);
    }

    function actorCount() external view returns (uint256) {
        return actors.length;
    }

    function actorAt(uint256 index) external view returns (address) {
        return actors[index];
    }
}
