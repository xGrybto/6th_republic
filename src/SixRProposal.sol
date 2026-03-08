// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/utils/structs/EnumerableMap.sol";
import "@openzeppelin/access/Ownable.sol";

import {Types} from "./Types.sol";

/// @title 6th Republic — SixRProposal
/// @notice Manages the full lifecycle of citizen proposals: creation, voting, and closure.
/// @dev Only callable by the owner (Orchestrator) for mutating functions, ensuring access control
///      is enforced upstream. Proposals follow a strict state machine: ENDED → CREATED → ONGOING → ENDED.
///      The ENDED state is also the default (zero-value), which is why proposalCounter starts at 1.
contract SixRProposal is Ownable {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using Types for Types.Category;
    using Types for Types.Vote;
    using Types for Types.Status;

    /// @notice Duration of the voting window after startVoting is called.
    uint256 public constant VOTING_PERIOD = 30 minutes;

    /// @notice Minimum delay between proposal creation and the opening of the voting window.
    uint256 public constant PREPARATION_PERIOD = 10 minutes;

    /// @notice Emitted when a new proposal is created.
    /// @param proposalId The ID of the newly created proposal.
    /// @param creator The address of the citizen who created the proposal.
    /// @param title The title of the proposal.
    event Created(
        uint256 indexed proposalId,
        address indexed creator,
        string title
    );

    /// @notice Emitted when the voting period for a proposal is opened.
    /// @param proposalId The ID of the proposal now in ONGOING status.
    event VoteStarted(uint256 indexed proposalId);

    /// @notice Emitted when a citizen successfully casts a vote.
    /// @param proposalId The ID of the proposal being voted on.
    /// @param voter The address of the citizen who voted.
    event Voted(uint256 indexed proposalId, address indexed voter);

    /// @notice Emitted when a proposal is closed.
    /// @param proposalId The ID of the closed proposal.
    /// @param _blockhash The hash of the block at closure time, used as a tamper-evidence seal.
    event Ended(uint256 indexed proposalId, bytes32 indexed _blockhash);

    /// @notice Full on-chain data structure for a proposal.
    struct Proposal {
        string title;
        string description;
        Types.Category category;
        address creator;
        /// @dev Timestamp of proposal creation (block.timestamp at creation).
        uint256 creationTime;
        /// @dev Timestamp when voting was opened (block.timestamp at startVoting call).
        uint256 votingTime;
        Types.Status status;
        /// @dev Maps voter address to their cast vote (as uint256 encoding of Types.Vote).
        EnumerableMap.AddressToUintMap votes;
        /// @dev Block hash at the time of closure, used as a tamper-evidence seal.
        bytes32 endBlockHash;
    }

    /// @notice Monotonically increasing counter used to assign proposal IDs.
    /// @dev Starts at 1. Proposal 0 is never created; its default ENDED status is exploited by
    ///      create() to allow the very first proposal to be submitted without a prior one.
    uint256 public proposalCounter;

    /// @dev Maps proposal ID to its full Proposal data.
    mapping(uint256 => Proposal) proposals;

    /// @notice Ensures the given proposal is in ENDED status.
    /// @param proposalId The ID of the proposal to check.
    modifier isEnded(uint256 proposalId) {
        require(
            proposals[proposalId].status == Types.Status.ENDED,
            "Current proposal is not yet voted"
        );
        _;
    }

    /// @notice Ensures the given proposal is in CREATED status (preparation period).
    /// @param proposalId The ID of the proposal to check.
    modifier isCreated(uint256 proposalId) {
        require(
            proposals[proposalId].status == Types.Status.CREATED,
            "The preparation period is over"
        );
        _;
    }

    /// @notice Initializes the contract and sets the proposal counter to 1.
    /// @dev Starting at 1 ensures proposal 0 never exists; its default ENDED status is used
    ///      as a precondition gate in create().
    constructor() Ownable(msg.sender) {
        proposalCounter = 1;
    }

    /* Proposal lifecycle function */

    /// @notice Creates a new proposal.
    /// @dev Only callable by the owner (Orchestrator). Requires the previous proposal (proposalCounter - 1)
    ///      to be in ENDED status, enforcing a single active proposal at a time. Proposal 0 is never
    ///      created, so its default ENDED status allows the first proposal to be submitted freely.
    /// @param sender The address of the citizen creating the proposal (passed by the Orchestrator).
    /// @param _title Short title of the proposal.
    /// @param _description Detailed description of the proposal.
    /// @param _category Domain category (ECOLOGY, EDUCATION, ECONOMY, DEFENSE).
    /// @return The ID of the newly created proposal.
    function create(
        address sender,
        string memory _title,
        string memory _description,
        Types.Category _category
    ) public onlyOwner isEnded(proposalCounter - 1) returns (uint256) {
        uint256 proposalId = proposalCounter;

        Proposal storage proposal = proposals[proposalId];
        proposal.title = _title;
        proposal.description = _description;
        proposal.category = _category;
        proposal.creator = sender;
        proposal.creationTime = block.timestamp;
        proposal.status = Types.Status.CREATED;

        emit Created(proposalId, sender, _title);

        proposalCounter++;

        return proposalId;
    }

    /* Proposal lifecycle function */

    /// @notice Opens the voting window for a proposal in CREATED status.
    /// @dev Only callable by the owner (Orchestrator). Reverts if the PREPARATION_PERIOD has not
    ///      elapsed since creation. Transitions the proposal to ONGOING status.
    /// @param proposalId The ID of the proposal to open for voting.
    function startVoting(
        uint256 proposalId
    ) public onlyOwner isCreated(proposalId) {
        Proposal storage proposal = proposals[proposalId];

        require(
            proposal.creationTime + PREPARATION_PERIOD < block.timestamp,
            "The vote is not open for voting yet"
        );

        proposal.status = Types.Status.ONGOING;
        emit VoteStarted(proposalId);
        proposal.votingTime = block.timestamp;
    }

    /* Proposal lifecycle function */

    /// @notice Records a citizen's vote on an ongoing proposal.
    /// @dev Only callable by the owner (Orchestrator). If the VOTING_PERIOD has elapsed since
    ///      startVoting, the proposal is automatically closed via close() and the function returns false.
    ///      Otherwise, validates the vote and records it. A voter can only vote once per proposal.
    ///      NULL votes are rejected. The vote value must be within the bounds of the Vote enum.
    /// @param proposalId The ID of the proposal to vote on.
    /// @param sender The address of the voting citizen (passed by the Orchestrator).
    /// @param _vote The vote choice. Must be YES or NO.
    /// @return True if the vote was successfully recorded; false if the voting period had expired.
    function vote(
        uint256 proposalId,
        address sender,
        Types.Vote _vote
    ) public onlyOwner returns (bool) {
        //Checks :
        // - que le citoyen est un passeport valide (ownsValidPassport)
        // - que le vote ne soit pas délégué (précaution)
        // - la personne n'a pas déjà voté
        // - le vote soit ouvert

        Proposal storage proposal = proposals[proposalId];
        require(
            proposals[proposalId].status == Types.Status.ONGOING,
            "The vote is not ongoing"
        ); // isOngoing
        if (proposal.votingTime + VOTING_PERIOD < block.timestamp) {
            close(proposalId);
            return false;
        } else {
            require(!proposal.votes.contains(sender), "You have already voted");
            require(_vote != Types.Vote.NULL, "The null vote is not accepted"); // isNotNull
            require(
                uint8(_vote) <= uint8(type(Types.Vote).max),
                "This value is not accepted as a vote"
            );
            proposal.votes.set(sender, uint256(_vote)); // No need to verify if the key is new because of the check on votes above
            emit Voted(proposalId, sender);
            return true;
        }
    }

    /// @notice Closes a proposal by setting its status to ENDED and recording the closing block hash.
    /// @dev Private. Called internally by vote() when the voting period has elapsed.
    ///      Uses blockhash(block.number - 1) as a tamper-evidence seal: the current block's hash is
    ///      not yet available to the EVM, so block.number would always return bytes32(0).
    /// @param proposalId The ID of the proposal to close.
    function close(uint256 proposalId) private {
        Proposal storage proposal = proposals[proposalId];
        proposal.status = Types.Status.ENDED;
        proposal.endBlockHash = blockhash(block.number - 1);
        emit Ended(proposalId, proposal.endBlockHash);
    }

    /// @notice Returns the list of all addresses that cast a vote on a given proposal.
    /// @dev Only callable by the owner (Orchestrator). Used by countVotes() to iterate over voters.
    /// @param proposalId The ID of the proposal.
    /// @return An array of voter addresses.
    function getVoters(
        uint256 proposalId
    ) public view onlyOwner returns (address[] memory) {
        Proposal storage proposal = proposals[proposalId];

        return proposal.votes.keys();
    }

    /// @notice Returns the raw vote value cast by a specific voter on a closed proposal.
    /// @dev Only callable by the owner (Orchestrator). Proposal must be in ENDED status.
    ///      The returned uint256 maps to Types.Vote (0 = NULL, 1 = NO, 2 = YES).
    /// @param proposalId The ID of the proposal (must be ENDED).
    /// @param voter The address of the voter to query.
    /// @return The uint256 encoding of the voter's Types.Vote choice.
    function getVote(
        uint256 proposalId,
        address voter
    ) public view onlyOwner isEnded(proposalId) returns (uint256) {
        Proposal storage proposal = proposals[proposalId];

        return proposal.votes.get(voter);
    }

    /// @notice Returns the public metadata of a proposal.
    /// @dev The votes map is excluded from the return value (not directly readable as a mapping).
    ///      Use getVoters + getVote to access individual vote data.
    /// @param proposalId The ID of the proposal to read.
    /// @return title The proposal title.
    /// @return description The proposal description.
    /// @return category The domain category.
    /// @return creator The address of the proposal creator.
    /// @return creationTime The block timestamp at creation.
    /// @return votingTime The block timestamp when voting starts.
    /// @return status The current status (ENDED, CREATED, or ONGOING).
    /// @return endBlockHash The block hash recorded at closure (bytes32(0) if not yet closed).
    function get(
        uint256 proposalId
    )
        public
        view
        returns (
            string memory,
            string memory,
            Types.Category category,
            address,
            uint256,
            uint256,
            Types.Status status,
            // EnumerableMap.AddressToUintMap,
            bytes32
        )
    {
        Proposal storage p = proposals[proposalId];
        return (
            p.title,
            p.description,
            p.category,
            p.creator,
            p.creationTime,
            p.votingTime,
            p.status,
            // p.votes,
            p.endBlockHash
        );
    }

    /// @notice Returns whether a given citizen has already voted on a proposal.
    /// @param proposalId The ID of the proposal.
    /// @param voter The address of the citizen to check.
    /// @return True if the citizen has cast a vote on this proposal.
    function hasVoted(
        uint256 proposalId,
        address voter
    ) public view returns (bool) {
        Proposal storage proposal = proposals[proposalId];

        return proposal.votes.contains(voter);
    }

    /// @notice Returns the current status of a proposal.
    /// @param proposalId The ID of the proposal.
    /// @return The current Types.Status (ENDED, CREATED, or ONGOING).
    function getStatus(uint256 proposalId) public view returns (Types.Status) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.status;
    }
}
