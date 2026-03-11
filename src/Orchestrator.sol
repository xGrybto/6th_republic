// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/access/Ownable.sol";

import {SixRPassport} from "./SixRPassport.sol";
import {SixRProposal} from "./SixRProposal.sol";
import {Types} from "./Types.sol";

/// @title 6th Republic — Orchestrator
/// @notice Central coordinator of the 6R voting system. Entry point for all citizen-facing actions.
/// @dev Deploys and owns SixRPassport and SixRProposal. Routes calls and enforces cross-contract rules
///      (passport ownership, delegation status). Vote counting with delegation weighting is performed here.
contract Orchestrator is Ownable {
    /// @notice Emitted when the votes of a closed proposal have been counted.
    /// @param proposalId The ID of the finalized proposal.
    /// @param yes Total weighted YES vote count (includes delegated power).
    /// @param no Total weighted NO vote count (includes delegated power).
    event ElectionResult(uint256 indexed proposalId, uint256 yes, uint256 no);

    /// @notice The SixRPassport contract instance managing citizen identity (SBT) and delegation.
    SixRPassport public passport;

    /// @notice The SixRProposal contract instance managing proposal lifecycle and votes.
    SixRProposal public proposal;

    /// @notice Deploys and initializes the SixRPassport and SixRProposal sub-contracts.
    constructor() Ownable(msg.sender) {
        passport = new SixRPassport();
        proposal = new SixRProposal();
    }

    /// @notice Restricts access to citizens who own a valid SixRPassport SBT.
    modifier ownsValidPassport() {
        require(
            passport.hasPassport(msg.sender),
            "The citizen doesn't own a SixRPassport SBT"
        );
        _;
    }

    /// @notice Restricts access to citizens who have not delegated their vote to a representative.
    modifier voteNotDelegated() {
        require(
            passport.s_representatives(msg.sender) == address(0), // != voting power, toujours 1 ou 0 => OK
            "Restricted : You have delegated your vote"
        );
        _;
    }

    //// Passport functionnalities /////
    // This could be also done without direct dependancy to the Orchestrator, but for what purpose ? Using passport in another context ?

    /// @notice Mints a new SixRPassport SBT for yourself
    /// @dev Each address can only hold one passport.
    ///      Delegates to SixRPassport.safeMint.
    /// @param p_pseudo First name of the citizen.
    /// @param nationality Nationality of the citizen.
    function mintPassport(
        string memory p_pseudo,
        string memory nationality
    ) external {
        passport.safeMint(msg.sender, p_pseudo, nationality);
    }

    //// Proposal functionnalities ////

    /// @notice Creates a new proposal on behalf of the calling citizen.
    /// @dev Caller must own a valid passport. The previous proposal must be in ENDED status before
    ///      a new one can be created. Delegates to SixRProposal.create.
    /// @param _title Short title of the proposal.
    /// @param _description Detailed description of the proposal.
    /// @return The ID of the newly created proposal.
    function createProposal(
        string memory _title,
        string memory _description
    ) public ownsValidPassport returns (uint256) {
        uint256 id = proposal.create(msg.sender, _title, _description);
        return id;
    }

    /// @notice Opens the voting period for a given proposal and pauses SixRPassport state changes.
    /// @dev Pausing the passport prevents delegation modifications during the voting period.
    ///      The proposal must be in CREATED status and past its PREPARATION_PERIOD.
    /// @param proposalId The ID of the proposal to transition to ONGOING status.
    function startVoting(uint256 proposalId) public {
        proposal.startVoting(proposalId);
        passport.pauseContract(true);
    }

    /// @notice Casts a vote on an ongoing proposal on behalf of the calling citizen.
    /// @dev Requires the caller to own a valid passport and not have delegated their vote.
    ///      If the voting period has expired at the time of the call, the proposal is automatically
    ///      closed, the passport is unpaused, and an ElectionResult event is emitted.
    /// @param proposalId The ID of the proposal to vote on.
    /// @param vote The vote choice. Must be YES or NO (NULL is rejected).
    /// @return True if the vote was successfully cast; false if the voting period had expired and
    ///         the proposal was closed instead.
    function voteProposal(
        uint256 proposalId,
        Types.Vote vote
    ) public ownsValidPassport voteNotDelegated returns (bool) {
        bool voted = proposal.vote(proposalId, msg.sender, vote);

        if (!voted) {
            passport.pauseContract(false);
            (uint256 yes_count, uint256 no_count) = countVotes(proposalId);
            emit ElectionResult(proposalId, yes_count, no_count);
        }

        return voted;
    }

    /// @notice Counts and returns the weighted vote results for a closed proposal.
    /// @dev Vote weighting: a delegate who voted counts for `delegatePower + 1` votes (their own
    ///      citizen vote plus one per citizen who delegated to them). A non-delegate counts for 1.
    ///      Reverts if the proposal is not in ENDED status.
    /// @param proposalId The ID of the proposal to tally (must be in ENDED status).
    /// @return yes Total weighted YES vote count.
    /// @return no Total weighted NO vote count.
    function countVotes(
        uint256 proposalId
    ) public view returns (uint256 yes, uint256 no) {
        require(
            proposal.getStatus(proposalId) == Types.Status.ENDED,
            "The vote is not closed yet"
        );
        address[] memory voters = proposal.getVoters(proposalId);

        uint256[3] memory result;

        for (uint256 index = 0; index < voters.length; index++) {
            address voter = voters[index];
            if (passport.s_delegatedMode(voter)) {
                result[proposal.getVote(proposalId, voter)] +=
                    passport.s_delegatePowers(voter) +
                    1; // Vote attribution : delegatePower + citizenVote (1)
            } else {
                result[proposal.getVote(proposalId, voter)]++; // Vote attribution : citizenVote (1)
            }
        }

        return (
            result[uint256(Types.Vote.YES)],
            result[uint256(Types.Vote.NO)]
        );
    }
}
