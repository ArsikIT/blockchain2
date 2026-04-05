// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Script} from "forge-std/Script.sol";
import {MockERC20} from "../../src/task1/MockERC20.sol";

contract DeployMockERC20 is Script {
    function run() external returns (MockERC20 token) {
        vm.startBroadcast();
        token = new MockERC20("Assignment Token", "ATK");
        vm.stopBroadcast();
    }
}
