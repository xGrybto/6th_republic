// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SixRPassport} from "../src/SixRPassport.sol";
import {SixRProposal} from "../src/SixRProposal.sol";
import {Orchestrator} from "../src/Orchestrator.sol";
import {Types} from "../src/Types.sol";
import {Test, console} from "forge-std/Test.sol";

contract OrchestratorTest is Test {
    using Types for Types.Category;
    SixRPassport private sixRPassport;
    SixRProposal private sixRProposal;
    Orchestrator private orchestrator;

    address owner = address(0x010);
    address citizen_1 = address(0x01);
    address citizen_2 = address(0x02);
    address citizen_3 = address(0x03);
    address citizen_4 = address(0x04);

    function setUp() public {
        vm.startPrank(owner);
        sixRPassport = new SixRPassport();
        sixRProposal = new SixRProposal();
        orchestrator = new Orchestrator(
            address(sixRPassport),
            address(sixRProposal)
        );
        vm.stopPrank();
        mintPassports();
    }

    function mintPassports() public {
        vm.startPrank(owner);
        sixRPassport.safeMint(
            citizen_1,
            "Marc",
            "JOTE",
            "Francais",
            "01/05/2000",
            "Lille",
            "2m05"
        );
        sixRPassport.safeMint(
            citizen_2,
            "Jose",
            "Cuelva",
            "Francais",
            "27/09/1985",
            "Biarritz",
            "1m71"
        );
        sixRPassport.safeMint(
            citizen_3,
            "Eva",
            "Mava",
            "Francaise",
            "01/11/2007",
            "Biarritz",
            "1m71"
        );
        vm.stopPrank();
    }

    function createFirstProposal() public returns (uint256) {
        return
            orchestrator.createProposal(
                "First proposal",
                "This is the first proposal",
                Types.Category.ECOLOGY
            );
    }

    function test_createProposal() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        assertEq(id, 1);
    }

    function test_voteProposal() public {
        test_createProposal();

        vm.prank(citizen_1);
        bool voted = orchestrator.voteProposal(Types.Vote.YES);

        assertEq(voted, true);
    }

    function test_cantDelegateWhenVoteOngoing() public {
        test_createProposal();

        assertEq(sixRPassport.paused(), true);
        vm.prank(citizen_1);
        vm.expectRevert(
            "The passport contract is paused for now, no changing state allowed."
        );
        sixRPassport.delegateVoteTo(citizen_2);
    }

    function test_cantCreatePassportWhenVoteOnGoing() public {
        test_createProposal();

        vm.prank(owner);
        vm.expectRevert(
            "The passport contract is paused for now, no changing state allowed."
        );
        sixRPassport.safeMint(
            citizen_4,
            "Paul",
            "Nepamint",
            "Francais",
            "09/02/1941",
            "Brest",
            "1m72"
        );
    }
}
