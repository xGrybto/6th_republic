// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {Orchestrator} from "../src/Orchestrator.sol";

contract DeployOrchestrator is Script {
    function run() external returns (Orchestrator) {
        string memory baseImageURI = vm.envString("PASSPORT_BASE_IMAGE_URI");
        string[] memory imageColors = vm.envString("PASSPORT_IMAGE_COLORS", ",");

        vm.startBroadcast();
        Orchestrator orchestrator = new Orchestrator();
        orchestrator.setPassportImageConfig(baseImageURI, imageColors);
        vm.stopBroadcast();

        return orchestrator;
    }
}
