// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/utils/Strings.sol";
import "@openzeppelin/utils/Base64.sol";
import "@openzeppelin/utils/structs/EnumerableMap.sol";
import "@openzeppelin/access/Ownable.sol";

import {SixRPassport} from "./SixRPassport.sol";
import {Types} from "./Types.sol";

contract SixRProposal is Ownable {
    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using Types for Types.Category;
    using Types for Types.Vote;
    using Types for Types.Status;

    uint256 constant VOTING_PERIOD = 3 days;
    uint256 constant PREPARATION_PERIOD = 1 days;

    event Created(
        uint256 indexed proposalId,
        address indexed creator,
        string title
    );

    event VoteStarted(uint256 indexed proposalId);

    event Voted(uint256 indexed proposalId, address indexed voter);

    event Ended(uint256 indexed proposalId, bytes32 indexed _blockhash);

    struct Proposal {
        string title;
        string description;
        Types.Category category;
        address creator;
        uint256 creationTime;
        uint256 votingTime;
        Types.Status status;
        EnumerableMap.AddressToUintMap votes; // address => Vote
        bytes32 endBlockHash;
    }

    uint256 public proposalCounter;
    mapping(uint256 => Proposal) proposals;

    modifier isEnded(uint256 proposalId) {
        require(
            proposals[proposalId].status == Types.Status.ENDED,
            "Current proposal is not yet voted"
        );
        _;
    }

    modifier isCreated(uint256 proposalId) {
        require(
            proposals[proposalId].status == Types.Status.CREATED,
            "The preparation period is over"
        );
        _;
    }

    constructor() Ownable(msg.sender) {
        proposalCounter = 1;
    }

    /* Proposal lifecycle function */
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
            proposal.votes.set(sender, uint256(_vote)); // No need to verify if the key is new because of the check on votes above
            emit Voted(proposalId, sender);
            return true;
        }
    }

    function close(uint256 proposalId) private {
        Proposal storage proposal = proposals[proposalId];
        proposal.status = Types.Status.ENDED;
        proposal.endBlockHash = blockhash(block.number);
        emit Ended(proposalId, proposal.endBlockHash);
    }

    function getVoters(
        uint256 proposalId
    ) public view onlyOwner returns (address[] memory) {
        Proposal storage proposal = proposals[proposalId];

        return proposal.votes.keys();
    }

    function getVote(
        uint256 proposalId,
        address voter
    ) public view onlyOwner isEnded(proposalId) returns (uint256) {
        Proposal storage proposal = proposals[proposalId];

        return proposal.votes.get(voter);
    }

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
            p.status,
            // p.votes,
            p.endBlockHash
        );
    }

    function hasVoted(
        uint256 proposalId,
        address voter
    ) public view returns (bool) {
        Proposal storage proposal = proposals[proposalId];

        return proposal.votes.contains(voter);
    }

    function getStatus(uint256 proposalId) public view returns (Types.Status) {
        Proposal storage proposal = proposals[proposalId];
        return proposal.status;
    }
}
