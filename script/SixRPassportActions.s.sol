// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.20;

import {Script} from "forge-std/Script.sol";
import {SixRPassport} from "../src/SixRPassport.sol";
import {Test, console} from "forge-std/Test.sol";

contract SixRPassportActions is Script {
    address me = 0x77f3650A6B8AeBa9A72b546749D3Da0E4518C6e8;

    function run() public {
        // address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment(
        //     "SixRPassport",
        //     block.chainid
        // );
        address mostRecentlyDeployed = 0xdC4Ff3e0486B0dAA5FAC309Fe441e75578a62156; //First Draft
        mintNftOnContract(mostRecentlyDeployed);
    }

    function mintNftOnContract(address contractAddress) public {
        vm.startBroadcast();
        SixRPassport(contractAddress).safeMint(
            me,
            "Alice",
            "Bob",
            "French",
            "11/06/1990",
            "Paris",
            "1m60"
        );
        vm.stopBroadcast();
        console.log(SixRPassport(contractAddress).tokenURI(1));
    }
}
