// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SixRPassport} from "../src/SixRPassport.sol";
import {SixRProposal} from "../src/SixRProposal.sol";
import {Orchestrator} from "../src/Orchestrator.sol";
import {Types} from "../src/Types.sol";
import {Test, console} from "forge-std/Test.sol";

contract OrchestratorTest is Test {
    using Types for Types.Category;
    SixRPassport private passport;
    SixRProposal private proposal;
    Orchestrator private orchestrator;

    address owner = address(0x010);
    address citizen_1 = address(0x01);
    address citizen_2 = address(0x02);
    address citizen_3 = address(0x03);
    address citizen_4 = address(0x04);

    function setUp() public {
        vm.prank(owner);
        orchestrator = new Orchestrator();
        passport = SixRPassport(orchestrator.passport());
        proposal = SixRProposal(orchestrator.proposal());
        mintThreePassports();
    }

    function mintThreePassports() public {
        vm.startPrank(address(orchestrator)); //TODO : to remove later
        passport.safeMint(
            citizen_1,
            "Marc",
            "JOTE",
            "Francais",
            "01/05/2000",
            "Lille",
            "2m05"
        );
        passport.safeMint(
            citizen_2,
            "Jose",
            "Cuelva",
            "Francais",
            "27/09/1985",
            "Biarritz",
            "1m71"
        );
        passport.safeMint(
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

    /***************************************/
    //            SIMPLE PROCESS          //
    /*************************************/

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

        ) = proposal.get(id);
        assertEq(id, 1);
        assertEq(title, "First proposal");
        assertEq(description, "This is the first proposal");
        assertEq(uint(category), uint(Types.Category.ECOLOGY));
        assertEq(creator, citizen_1);
        assertEq(uint(status), uint(Types.Status.ONGOING));
    }

    function test_voteProposal() public {
        test_createProposal();

        vm.prank(citizen_1);
        bool voted = orchestrator.voteProposal(Types.Vote.YES);

        assertEq(voted, true);
    }

    function test_createProposalThroughProposalContract() public {
        vm.prank(citizen_1);
        vm.expectRevert();
        proposal.create(
            citizen_1,
            "First proposal",
            "This is the first proposal",
            Types.Category.ECOLOGY
        );
    }

    function test_voteProposalThroughProposalContract() public {
        test_createProposal();

        vm.prank(citizen_1);
        vm.expectRevert();
        proposal.vote(msg.sender, Types.Vote.YES);
    }

    function test_getVoters() public {
        test_createProposal();

        vm.prank(citizen_1);
        bool voted_1 = orchestrator.voteProposal(Types.Vote.YES);
        vm.prank(citizen_2);
        bool voted_2 = orchestrator.voteProposal(Types.Vote.NO);
        vm.prank(citizen_3);
        bool voted_3 = orchestrator.voteProposal(Types.Vote.YES);

        assertEq(voted_1, true);
        assertEq(voted_2, true);
        assertEq(voted_3, true);

        address[] memory voters = proposal.getVoters();

        assertEq(voters.length, 3);
        assertEq(voters[0], citizen_1);
        assertEq(voters[1], citizen_2);
        assertEq(voters[2], citizen_3);
    }

    function test_getVoterResult() public {
        test_createProposal();

        vm.prank(citizen_1);
        orchestrator.voteProposal(Types.Vote.YES);

        vm.warp(block.timestamp + 3 days + 1 seconds);

        vm.prank(citizen_2);
        orchestrator.voteProposal(Types.Vote.YES);

        address[] memory voters = proposal.getVoters();

        assertEq(proposal.getVoterResult(voters[0]), 2);
    }

    //TODO : Test on counting vote with delegation, with multiple voters
    function test_electionWithDelegation() public {
        address delegate_1 = address(0x10); // with vote
        address delegate_2 = address(0x11); //without vote
        vm.startPrank(address(orchestrator)); //TODO : to remove later
        passport.safeMint(
            delegate_1,
            "Samantha",
            "Delo",
            "Francais",
            "04/10/1997",
            "Quimper",
            "1m66"
        );
        passport.safeMint(
            delegate_2,
            "Delpielo",
            "Gator",
            "Francais",
            "31/12/1980",
            "Rennes",
            "1m76"
        );
        vm.stopPrank();

        vm.prank(delegate_1);
        passport.enableDelegatedMode();
        vm.prank(delegate_2);
        passport.enableDelegatedMode();

        vm.prank(citizen_1);
        passport.delegateVoteTo(delegate_1);

        vm.prank(citizen_2);
        passport.delegateVoteTo(delegate_1);

        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        vm.prank(delegate_1);
        orchestrator.voteProposal(Types.Vote.YES);

        vm.prank(delegate_2);
        orchestrator.voteProposal(Types.Vote.NO);

        vm.prank(citizen_3);
        orchestrator.voteProposal(Types.Vote.NO);

        vm.warp(block.timestamp + 3 days + 1 seconds);

        // Call to close the vote
        vm.prank(delegate_1);
        orchestrator.voteProposal(Types.Vote.YES);

        address[] memory voters = proposal.getVoters();

        assertEq(proposal.getVoterResult(voters[0]), 2);
        assertEq(proposal.getVoterResult(voters[1]), 1);
        assertEq(proposal.getVoterResult(voters[2]), 1);

        orchestrator.countVotes();
    }

    /***************************************/
    //            PROPOSAL STATUS         //
    /*************************************/
    function test_createAProposalDuringOngoingProposal() public {
        test_createProposal();
        vm.prank(citizen_2);
        vm.expectRevert("Current proposal is not yet voted");
        orchestrator.createProposal(
            "Second proposal",
            "This is the second proposal",
            Types.Category.EDUCATION
        );
    }

    function test_createAProposalWhenCountingState() public {
        test_createProposal();

        vm.warp(block.timestamp + 3 days + 1 seconds);

        // Change state to "Counting"
        vm.prank(citizen_1);
        orchestrator.voteProposal(Types.Vote.YES);

        vm.prank(citizen_2);
        vm.expectRevert("Current proposal is not yet voted");
        orchestrator.createProposal(
            "Second proposal",
            "This is the second proposal",
            Types.Category.EDUCATION
        );
    }

    function test_passportActionsWhenCountingState() public {
        test_createProposal();

        vm.warp(block.timestamp + 3 days + 1 seconds);

        // Change state to "Counting"
        vm.prank(citizen_1);
        orchestrator.voteProposal(Types.Vote.YES);

        vm.prank(citizen_1);
        vm.expectRevert(
            "The passport contract is paused for now, no changing state allowed."
        );
        passport.delegateVoteTo(citizen_2);
    }

    function test_createProposalAfterPreviousProposal() public {
        test_createProposal();
        vm.warp(block.timestamp + 3 days + 1 seconds);

        // Close the voting period by calling voteProposal function after 3 days
        vm.prank(citizen_1);
        orchestrator.voteProposal(Types.Vote.YES);

        // End the proposal by counting votes
        orchestrator.countVotes();

        vm.prank(citizen_2);
        orchestrator.createProposal(
            "Second proposal",
            "This is the second proposal",
            Types.Category.EDUCATION
        );
    }

    function test_closeProposal() public {
        vm.startPrank(citizen_1);
        uint256 id = createFirstProposal();
        vm.warp(block.timestamp + 3 days + 1 seconds);
        // This call will close the vote of the proposal
        bool voted = orchestrator.voteProposal(Types.Vote.YES);
        assertEq(voted, false);
        (, , , , , Types.Status status, ) = proposal.get(id);
        assertEq(uint(status), uint(Types.Status.COUNTING));
        // This call will be refused because the status of the proposal
        vm.expectRevert("Proposal voted, vote is not accepted anymore");
        voted = orchestrator.voteProposal(Types.Vote.YES);
        vm.stopPrank();
    }

    function test_countResult() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        vm.prank(citizen_1);
        orchestrator.voteProposal(Types.Vote.YES);

        vm.prank(citizen_2);
        orchestrator.voteProposal(Types.Vote.YES);

        vm.warp(block.timestamp + 3 days + 1 seconds);

        vm.prank(citizen_3);
        orchestrator.voteProposal(Types.Vote.YES);

        orchestrator.countVotes();

        (, , , , , Types.Status status, ) = proposal.get(id);

        assertEq(uint(status), uint(Types.Status.ENDED));
    }

    function test_closeProposalWithCitizenThatHasVoted() public {
        vm.startPrank(citizen_1);
        uint256 id = createFirstProposal();

        bool voted = orchestrator.voteProposal(Types.Vote.YES);

        assertEq(voted, true);

        vm.warp(block.timestamp + 3 days + 1 seconds);
        // This call will close the vote of the proposal
        bool voted_2 = orchestrator.voteProposal(Types.Vote.YES);
        assertEq(voted_2, false);
        (, , , , , Types.Status status, ) = proposal.get(id);
        assertEq(uint(status), uint(Types.Status.COUNTING));
        // This call will be refused because the status of the proposal
        vm.expectRevert("Proposal voted, vote is not accepted anymore");
        voted = orchestrator.voteProposal(Types.Vote.YES);
        vm.stopPrank();
    }

    /***************************************/
    //            VOTING                  //
    /*************************************/

    function test_voteOneTime() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        vm.prank(citizen_2);
        bool voted = orchestrator.voteProposal(Types.Vote.YES);

        assertEq(voted, true);
        assertEq(proposal.hasVoted(id, citizen_2), true);
    }

    //Vote two times => revert
    function test_voteTwoTimes() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        vm.startPrank(citizen_2);
        orchestrator.voteProposal(Types.Vote.YES);
        vm.expectRevert("You have already voted");
        orchestrator.voteProposal(Types.Vote.NO);
        vm.stopPrank();
    }

    //Process functionnal even if nobody vote the proposal
    function test_countVotesWithoutAnyVote() public {
        test_createProposal();

        vm.warp(block.timestamp + 3 days + 1 seconds);

        vm.prank(citizen_1);
        orchestrator.voteProposal(Types.Vote.YES);

        orchestrator.countVotes();
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

        assertEq(passport.hasPassport(citizen_4), false);

        vm.prank(citizen_4);
        vm.expectRevert("The citizen doesn't own a SixRPassport SBT");
        orchestrator.voteProposal(Types.Vote.YES);
    }

    /***************************************/
    //      TEST PAUSE FUNCTIONNALITY     //
    /*************************************/

    function test_pausePassportNotOwner() public {
        vm.prank(citizen_1);
        vm.expectRevert();
        passport.pauseContract(true);
    }

    function test_cantDelegateWhenVoteOngoing() public {
        test_createProposal();

        assertEq(passport.paused(), true);
        vm.prank(citizen_1);
        vm.expectRevert(
            "The passport contract is paused for now, no changing state allowed."
        );
        passport.delegateVoteTo(citizen_2);
    }

    function test_cantCreatePassportWhenVoteOnGoing() public {
        test_createProposal();

        vm.prank(address(orchestrator));
        vm.expectRevert(
            "The passport contract is paused for now, no changing state allowed."
        );
        passport.safeMint(
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
