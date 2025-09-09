// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {SixRPassport} from "../src/SixRPassport.sol";

contract DeploySixRPassport is Script {
    function run() external returns (SixRPassport) {
        vm.startBroadcast();
        SixRPassport sixRPassport = new SixRPassport();
        vm.stopBroadcast();
        return sixRPassport;
    }
}
