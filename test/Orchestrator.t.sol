// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {SixRPassport} from "../src/SixRPassport.sol";
import {SixRProposal} from "../src/SixRProposal.sol";
import {Orchestrator} from "../src/Orchestrator.sol";
import {Types} from "../src/Types.sol";
import {Test, console} from "forge-std/Test.sol";

contract OrchestratorTest is Test {
    SixRPassport private passport;
    SixRProposal private proposal;
    Orchestrator private orchestrator;

    uint256 constant VOTING_PERIOD = 30 minutes;
    uint256 constant PREPARATION_PERIOD = 10 minutes;

    event MintPassport(
        uint256 indexed passportId,
        address indexed citizen,
        string pseudo
    );

    event Created(
        uint256 indexed proposalId,
        address indexed creator,
        string title
    );

    event VoteStarted(uint256 indexed proposalId);

    event Voted(uint256 indexed proposalId, address indexed voter);

    event Ended(uint256 indexed proposalId, bytes32 indexed _blockhash);

    event ElectionResult(uint256 indexed proposalId, uint256 yes, uint256 no);

    event DelegatedModeEnabled(address indexed citizen);

    event DelegatedModeDisabled(address indexed citizen);

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
        vm.prank(citizen_1);
        orchestrator.mintPassport("Marc", "Francais");
        vm.prank(citizen_2);
        orchestrator.mintPassport("Jose", "Francais");
        vm.prank(citizen_3);
        orchestrator.mintPassport("Eva", "Francais");
    }

    function createFirstProposal() public returns (uint256) {
        return
            orchestrator.createProposal(
                "First proposal",
                "This is the first proposal"
            );
    }

    function createAndStartVotingProposal() public returns (uint256) {
        uint256 id = createFirstProposal();

        vm.warp(block.timestamp + PREPARATION_PERIOD + 1 seconds);
        orchestrator.startVoting(id);

        return id;
    }

    //            SIMPLE PROCESS          //

    function test_createProposal() public {
        vm.prank(citizen_1);
        vm.expectEmit(true, true, false, true);
        emit Created(1, citizen_1, "First proposal");
        uint256 id = createFirstProposal();

        (
            string memory title,
            string memory description,
            address creator,
            ,
            ,
            Types.Status status,

        ) = proposal.get(id);
        assertEq(id, 1);
        assertEq(title, "First proposal");
        assertEq(description, "This is the first proposal");
        assertEq(creator, citizen_1);
        assertEq(uint256(status), uint256(Types.Status.CREATED));
    }

    function test_createAndStartVotingProposal() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        vm.warp(block.timestamp + PREPARATION_PERIOD + 1 seconds);
        vm.expectEmit();
        emit VoteStarted(1);

        orchestrator.startVoting(id);
    }

    function test_createButCantStartVoting() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        vm.expectRevert("The vote is not open for voting yet");
        orchestrator.startVoting(id);
    }

    function test_voteProposal() public {
        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.prank(citizen_1);
        vm.expectEmit();
        emit Voted(1, citizen_1);
        bool voted = orchestrator.voteProposal(id, Types.Vote.YES);

        assertEq(voted, true);
    }

    function test_cantCreateProposalThroughProposalContract() public {
        vm.prank(citizen_1);
        vm.expectRevert();
        proposal.create(
            citizen_1,
            "First proposal",
            "This is the first proposal"
        );
    }

    function test_cantVoteProposalThroughProposalContract() public {
        vm.prank(citizen_1);
        uint256 id = createFirstProposal();

        vm.prank(citizen_1);
        vm.expectRevert();
        proposal.vote(id, msg.sender, Types.Vote.YES);
    }

    function test_getVoters() public {
        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.prank(citizen_1);
        bool voted_1 = orchestrator.voteProposal(id, Types.Vote.YES);
        vm.prank(citizen_2);
        bool voted_2 = orchestrator.voteProposal(id, Types.Vote.NO);
        vm.prank(citizen_3);
        bool voted_3 = orchestrator.voteProposal(id, Types.Vote.YES);

        assertEq(voted_1, true);
        assertEq(voted_2, true);
        assertEq(voted_3, true);

        vm.prank(address(orchestrator));
        address[] memory voters = proposal.getVoters(id);

        assertEq(voters.length, 3);
        assertEq(voters[0], citizen_1);
        assertEq(voters[1], citizen_2);
        assertEq(voters[2], citizen_3);
    }

    function test_getVote() public {
        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.prank(citizen_1);
        orchestrator.voteProposal(id, Types.Vote.YES);

        vm.warp(block.timestamp + VOTING_PERIOD + 1 seconds);

        vm.prank(citizen_2);
        vm.expectEmit();
        emit Ended(1, blockhash(block.number - 1));
        orchestrator.voteProposal(id, Types.Vote.YES);

        vm.startPrank(address(orchestrator));
        address[] memory voters = proposal.getVoters(id);

        assertEq(proposal.getVote(id, voters[0]), 2);
        vm.stopPrank();
    }

    function test_successfullElectionWithDelegation() public {
        address delegate_1 = address(0x10); // with vote
        address delegate_2 = address(0x11); //without vote
        vm.prank(delegate_1);
        orchestrator.mintPassport("Samantha", "Francais");
        vm.prank(delegate_2);
        orchestrator.mintPassport("Delpielo", "Francais");

        vm.prank(delegate_1);
        passport.enableDelegatedMode();
        vm.prank(delegate_2);
        passport.enableDelegatedMode();

        vm.prank(citizen_1);
        passport.delegateVoteTo(delegate_1);

        vm.prank(citizen_2);
        passport.delegateVoteTo(delegate_1);

        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.prank(delegate_1);
        orchestrator.voteProposal(id, Types.Vote.YES);

        vm.prank(delegate_2);
        orchestrator.voteProposal(id, Types.Vote.NO);

        vm.prank(citizen_3);
        orchestrator.voteProposal(id, Types.Vote.NO);

        vm.warp(block.timestamp + VOTING_PERIOD + 1 seconds);

        // Call to close the vote
        vm.prank(delegate_1);
        vm.expectEmit();
        emit ElectionResult(id, 3, 2);
        orchestrator.voteProposal(id, Types.Vote.YES);

        vm.startPrank(address(orchestrator));
        address[] memory voters = proposal.getVoters(id);

        assertEq(proposal.getVote(id, voters[0]), 2);
        assertEq(proposal.getVote(id, voters[1]), 1);
        assertEq(proposal.getVote(id, voters[2]), 1);
        vm.stopPrank();
    }

    function test_refusedElectionWithDelegation() public {
        address delegate_1 = address(0x10);
        address delegate_2 = address(0x11);

        vm.prank(delegate_1);
        orchestrator.mintPassport("Samantha", "Francais");
        vm.prank(delegate_2);
        orchestrator.mintPassport("Delpielo", "Francais");

        vm.prank(delegate_1);
        passport.enableDelegatedMode();
        vm.prank(delegate_2);
        passport.enableDelegatedMode();

        vm.prank(citizen_1);
        passport.delegateVoteTo(delegate_1);

        vm.prank(citizen_2);
        passport.delegateVoteTo(delegate_2);

        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.prank(delegate_1);
        orchestrator.voteProposal(id, Types.Vote.YES);

        vm.prank(delegate_2);
        orchestrator.voteProposal(id, Types.Vote.NO);

        vm.prank(citizen_3);
        orchestrator.voteProposal(id, Types.Vote.NO);

        vm.warp(block.timestamp + VOTING_PERIOD + 1 seconds);

        // Call to close the vote
        vm.prank(delegate_1);
        vm.expectEmit();
        emit ElectionResult(id, 2, 3);
        orchestrator.voteProposal(id, Types.Vote.YES);

        vm.startPrank(address(orchestrator));
        address[] memory voters = proposal.getVoters(id);

        assertEq(proposal.getVote(id, voters[0]), 2);
        assertEq(proposal.getVote(id, voters[1]), 1);
        assertEq(proposal.getVote(id, voters[2]), 1);
        vm.stopPrank();
    }

    //            PROPOSAL STATUS         //

    function test_cantCreateAProposalDuringOngoingProposal() public {
        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.prank(citizen_2);
        vm.expectRevert("Current proposal is not yet voted");
        orchestrator.createProposal(
            "Second proposal",
            "This is the second proposal"
        );
    }

    function test_createProposalAfterPreviousProposal() public {
        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.warp(block.timestamp + VOTING_PERIOD + 1 seconds);

        // Close the voting period by calling voteProposal function after 3 days
        vm.prank(citizen_1);
        orchestrator.voteProposal(id, Types.Vote.YES);

        // End the proposal by counting votes
        orchestrator.countVotes(id);

        vm.prank(citizen_2);
        vm.expectEmit();
        emit Created(2, citizen_2, "Second proposal");
        orchestrator.createProposal(
            "Second proposal",
            "This is the second proposal"
        );
    }

    function test_closeProposalWithoutVote() public {
        vm.startPrank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.warp(block.timestamp + VOTING_PERIOD + 1 seconds);
        // This call will close the vote of the proposal
        vm.expectEmit();
        emit Ended(1, blockhash(block.number - 1));
        vm.expectEmit();
        emit ElectionResult(id, 0, 0);
        bool voted = orchestrator.voteProposal(id, Types.Vote.YES);
        assertEq(voted, false);

        (, , , , , Types.Status status, ) = proposal.get(id);
        assertEq(uint256(status), uint256(Types.Status.ENDED));

        vm.stopPrank();
    }

    function test_cantVoteClosedProposal() public {
        vm.startPrank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        bool voted = orchestrator.voteProposal(id, Types.Vote.YES);

        assertEq(voted, true);

        vm.warp(block.timestamp + VOTING_PERIOD + 1 seconds);
        // This call will close the vote of the proposal
        bool voted_2 = orchestrator.voteProposal(id, Types.Vote.YES);
        assertEq(voted_2, false);
        (, , , , , Types.Status status, ) = proposal.get(id);
        assertEq(uint256(status), uint256(Types.Status.ENDED));
        // This call will be refused because the status of the proposal
        vm.expectRevert("The vote is not ongoing");
        voted = orchestrator.voteProposal(id, Types.Vote.YES);
        vm.stopPrank();
    }

    //            VOTING                  //

    function test_voteOneTime() public {
        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.prank(citizen_2);
        bool voted = orchestrator.voteProposal(id, Types.Vote.YES);

        assertEq(voted, true);
        assertEq(proposal.hasVoted(id, citizen_2), true);
    }

    //Vote two times => revert
    function test_voteTwoTimes() public {
        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.startPrank(citizen_2);
        orchestrator.voteProposal(id, Types.Vote.YES);
        vm.expectRevert("You have already voted");
        orchestrator.voteProposal(id, Types.Vote.NO);
        vm.stopPrank();
    }

    //            WITHOUT PASSPORT        //

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
        uint256 id = createAndStartVotingProposal();

        assertEq(passport.hasPassport(citizen_4), false);

        vm.prank(citizen_4);
        vm.expectRevert("The citizen doesn't own a SixRPassport SBT");
        orchestrator.voteProposal(id, Types.Vote.YES);
    }

    //      TEST PAUSE FUNCTIONNALITY     //

    function test_pausePassportNotOwner() public {
        vm.prank(citizen_1);
        vm.expectRevert();
        passport.pauseContract(true);
    }

    function test_cantDelegateWhenVoteOngoing() public {
        vm.prank(citizen_2);
        uint256 id = createFirstProposal();

        assertEq(passport.paused(), false);

        vm.prank(citizen_2);

        passport.enableDelegatedMode();

        vm.warp(block.timestamp + PREPARATION_PERIOD + 1 seconds);

        assertEq(passport.paused(), false);

        orchestrator.startVoting(id);

        assertEq(passport.paused(), true);

        vm.prank(citizen_1);
        vm.expectRevert(
            "The passport contract is paused for now, no changing state allowed."
        );
        passport.delegateVoteTo(citizen_2);
    }

    function test_createPassportWhenVoteCreated() public {
        test_createProposal();

        vm.prank(citizen_4);
        vm.expectEmit();
        emit MintPassport(4, citizen_4, "Paul");
        orchestrator.mintPassport("Paul", "Francais");
    }

    function test_cantCreatePassportWhenVoteOnGoing() public {
        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.prank(citizen_4);
        vm.expectRevert(
            "The passport contract is paused for now, no changing state allowed."
        );
        orchestrator.mintPassport("Paul", "Francais");
    }

    // Election with revoke delegate that has vote delegated
    function test_electionWithRevokedDelegateStatus() public {
        address delegate_1 = address(0x10);

        vm.prank(delegate_1);
        orchestrator.mintPassport("Samantha", "Francais");

        vm.prank(delegate_1);
        passport.enableDelegatedMode();

        vm.prank(citizen_1);
        passport.delegateVoteTo(delegate_1);

        vm.prank(citizen_2);
        passport.delegateVoteTo(delegate_1);

        vm.prank(delegate_1);
        vm.expectEmit();
        emit DelegatedModeDisabled(delegate_1);
        passport.disableDelegatedMode();

        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.prank(delegate_1);
        orchestrator.voteProposal(id, Types.Vote.YES);

        vm.prank(citizen_1);
        vm.expectRevert("Restricted : You have delegated your vote");
        orchestrator.voteProposal(id, Types.Vote.NO);

        vm.warp(block.timestamp + VOTING_PERIOD + 1 seconds);

        // Call to close the vote
        vm.prank(delegate_1);
        vm.expectEmit();
        emit ElectionResult(id, 1, 0);
        orchestrator.voteProposal(id, Types.Vote.YES);

        vm.startPrank(address(orchestrator));
        address[] memory voters = proposal.getVoters(id);

        assertEq(proposal.getVote(id, voters[0]), 2);
        vm.stopPrank();
    }

    function test_electionWithPreviouslyRevokedDelegateStatus() public {
        address delegate_1 = address(0x10);

        vm.prank(delegate_1);
        orchestrator.mintPassport("Samantha", "Francais");

        vm.prank(delegate_1);
        passport.enableDelegatedMode();

        vm.prank(citizen_1);
        passport.delegateVoteTo(delegate_1);

        vm.prank(citizen_2);
        passport.delegateVoteTo(delegate_1);

        vm.startPrank(delegate_1);
        vm.expectEmit();
        emit DelegatedModeDisabled(delegate_1);
        passport.disableDelegatedMode();

        passport.enableDelegatedMode();

        vm.stopPrank();

        vm.prank(citizen_1);
        uint256 id = createAndStartVotingProposal();

        vm.prank(delegate_1);
        orchestrator.voteProposal(id, Types.Vote.YES);

        vm.prank(citizen_1);
        vm.expectRevert("Restricted : You have delegated your vote");
        orchestrator.voteProposal(id, Types.Vote.NO);

        vm.warp(block.timestamp + VOTING_PERIOD + 1 seconds);

        // Call to close the vote
        vm.prank(delegate_1);
        vm.expectEmit();
        emit ElectionResult(id, 3, 0);
        orchestrator.voteProposal(id, Types.Vote.YES);

        vm.startPrank(address(orchestrator));
        address[] memory voters = proposal.getVoters(id);

        assertEq(proposal.getVote(id, voters[0]), 2);
        vm.stopPrank();
    }
}
