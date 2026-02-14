// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Orchestrator} from "../src/Orchestrator.sol";

contract DeployOrchestrator is Script {
    function run() external returns (Orchestrator) {
        vm.startBroadcast();
        Orchestrator orchestrator = new Orchestrator();
        vm.stopBroadcast();
        return orchestrator;
    }
}
