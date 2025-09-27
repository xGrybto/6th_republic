// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SixRPassport} from "../src/SixRPassport.sol";
import {SixRProposal} from "../src/SixRProposal.sol";
import {Types} from "../src/Types.sol";
import {Test, console} from "forge-std/Test.sol";

contract SixRProposalTest is Test {
    using Types for Types.Category;
    SixRPassport private sixRPassport;
    SixRProposal private sixRProposal;

    address owner = address(0x010);
    address citizen_1 = address(0x01);
    address citizen_2 = address(0x02);
    address citizen_3 = address(0x03);
    address citizen_4 = address(0x04);

    function setUp() public {
        vm.startPrank(owner);
        sixRPassport = new SixRPassport();
        sixRProposal = new SixRProposal();
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
            sixRProposal.createProposal(
                msg.sender,
                "First proposal",
                "This is the first proposal",
                Types.Category.ECOLOGY
            );
    }

    /***************************************/
    //            PROPOSAL STATUS         //
    /*************************************/

    //Creating a proposal
    function test_createProposal() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        (
            string memory title,
            string memory description,
            Types.Category category,
            address creator,
            ,
            Types.Status status,

        ) = sixRProposal.getProposal(id);
        assertEq(id, 1);
        assertEq(title, "First proposal");
        assertEq(description, "This is the first proposal");
        assertEq(uint(category), uint(Types.Category.ECOLOGY));
        assertEq(creator, citizen_1);
        assertEq(uint(status), uint(Types.Status.ONGOING));
    }

    function test_createAProposalDuringOngoingProposal() public {
        test_createProposal();
        vm.prank(citizen_2);
        vm.expectRevert("Current proposal is not yet voted");
        sixRProposal.createProposal(
            msg.sender,
            "Second proposal",
            "This is the second proposal",
            Types.Category.EDUCATION
        );
    }

    function test_createProposalAfterPreviousProposal() public {
        test_createProposal();
        vm.warp(block.timestamp + 3 days + 1 seconds);

        // End the voting period by calling voteProposal function after 3 days
        vm.prank(citizen_1);
        sixRProposal.voteProposal(msg.sender, Types.Vote.YES);

        vm.prank(citizen_2);
        sixRProposal.createProposal(
            msg.sender,
            "Second proposal",
            "This is the second proposal",
            Types.Category.EDUCATION
        );
    }

    function test_endProposal() public {
        vm.startPrank(citizen_1);
        uint256 id = createFirstProposal();
        vm.warp(block.timestamp + 3 days + 1 seconds);
        // This call will close the vote of the proposal
        bool voted = sixRProposal.voteProposal(msg.sender, Types.Vote.YES);
        assertEq(voted, false);
        (, , , , , Types.Status status, ) = sixRProposal.getProposal(id);
        assertEq(uint(status), uint(Types.Status.ENDED));
        // This call will be refused because the status of the proposal
        vm.expectRevert("Proposal voted, vote is not accepted anymore");
        voted = sixRProposal.voteProposal(msg.sender, Types.Vote.YES);
        vm.stopPrank();
    }

    /***************************************/
    //            VOTING                  //
    /*************************************/

    function test_voteOneTime() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        vm.prank(citizen_2);
        bool voted = sixRProposal.voteProposal(msg.sender, Types.Vote.YES);

        assertEq(voted, true);
        assertEq(sixRProposal.hasVoted(id, citizen_2), true);
    }

    //Vote two times => revert
    function test_voteTwoTimes() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        vm.startPrank(citizen_2);
        sixRProposal.voteProposal(msg.sender, Types.Vote.YES);
        vm.expectRevert("You have already voted");
        sixRProposal.voteProposal(msg.sender, Types.Vote.NO);
        vm.stopPrank();
    }

    /***************************************/
    //            WITHOUT PASSPORT        //
    /*************************************/

    //Create proposal without passport

    function test_createProposalWithoutPassport() public {
        // Citizen 4 no passport
        vm.prank(citizen_4);
        vm.expectRevert("The citizen doesn't own a SixRPassport SBT");
        createFirstProposal();
    }

    //Vote without passport
    function test_voteWithoutPassport() public {
        vm.prank(citizen_1);
        createFirstProposal();

        assertEq(sixRPassport.hasPassport(citizen_4), false);

        vm.prank(citizen_4);
        vm.expectRevert("The citizen doesn't own a SixRPassport SBT");
        sixRProposal.voteProposal(msg.sender, Types.Vote.YES);
    }

    // Vote then delegate => accepted but your vote will count zero (future draft for counting vote)
    function test_voteThenDelegateAllowed() public {
        vm.startPrank(citizen_1);
        uint256 id = createFirstProposal();

        sixRProposal.voteProposal(msg.sender, Types.Vote.NO);
        assertEq(sixRPassport.s_votingPowers(citizen_1), 1);
        sixRPassport.delegateVoteTo(citizen_2);
        vm.stopPrank();

        assertEq(sixRPassport.s_representatives(citizen_1), citizen_2);
        assertEq(sixRPassport.s_votingPowers(citizen_1), 0);
        assertEq(sixRPassport.s_votingPowers(citizen_2), 2);

        assertEq(sixRProposal.hasVoted(id, citizen_1), true);
    }

    function test_delegateThenVoteNotAllowed() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        vm.prank(citizen_3);
        sixRPassport.delegateVoteTo(citizen_2);

        assertEq(sixRPassport.s_votingPowers(citizen_3), 0);
        assertEq(sixRPassport.hasPassport(citizen_3), true);

        vm.prank(citizen_3);
        vm.expectRevert("Restricted : You have delegated your vote");
        sixRProposal.voteProposal(msg.sender, Types.Vote.NO);
    }
}
