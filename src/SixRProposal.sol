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

    event Closed(uint256 indexed proposalId, bytes32 indexed _blockhash);

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
    mapping(uint256 => Proposal) proposals; //TODO: why a getter is needed to acces it, and not choose to put this mapping public ?

    modifier isEnded() {
        require(
            proposals[proposalCounter - 1].status == Types.Status.ENDED,
            "Current proposal is not yet voted"
        );
        _;
    }

    modifier isCreated() {
        require(
            proposals[proposalCounter - 1].status == Types.Status.CREATED,
            "The preparation period is over"
        );
        _;
    }

    modifier isOngoing() {
        require(
            proposals[proposalCounter - 1].status == Types.Status.ONGOING,
            "The vote is not ongoing"
        );
        _;
    }

    modifier isCounting() {
        require(
            proposals[proposalCounter - 1].status == Types.Status.COUNTING,
            "The counting of votes is over"
        );
        _;
    }

    modifier isNotNull(Types.Vote _vote) {
        require(_vote != Types.Vote.NULL);
        _;
    }

    constructor() Ownable(msg.sender) {
        proposalCounter = 1;
    }

    function create(
        address sender,
        string memory _title,
        string memory _description,
        Types.Category _category
    ) public onlyOwner isEnded returns (uint256) {
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

    function startVoting() public onlyOwner isCreated {
        uint256 proposalId = proposalCounter - 1;
        Proposal storage proposal = proposals[proposalId];

        require(
            proposal.creationTime + PREPARATION_PERIOD < block.timestamp,
            "The vote is not open for voting yet"
        );

        proposal.status = Types.Status.ONGOING;
        emit VoteStarted(proposalId);
        proposal.votingTime = block.timestamp;
    }

    function vote(
        address sender,
        Types.Vote _vote
    ) public onlyOwner isOngoing isNotNull(_vote) returns (bool) {
        //Checks :
        // - que le citoyen est un passeport valide (ownsValidPassport)
        // - que le vote ne soit pas délégué (précaution)
        // - la personne n'a pas déjà voté
        // - le vote soit ouvert
        uint256 proposalId = proposalCounter - 1;

        Proposal storage proposal = proposals[proposalId];
        if (proposal.votingTime + VOTING_PERIOD < block.timestamp) {
            closeElection(proposal);
            return false;
        } else {
            require(!proposal.votes.contains(sender), "You have already voted");
            proposal.votes.set(sender, uint256(_vote));
            emit Voted(proposalId, sender);
            return true;
        }
    }

    function closeElection(Proposal storage p) private {
        p.status = Types.Status.COUNTING;
        p.endBlockHash = blockhash(block.number);
        emit Closed(proposalCounter - 1, p.endBlockHash);
    }

    function getVoters() public view returns (address[] memory) {
        uint256 proposalId = proposalCounter - 1;
        Proposal storage proposal = proposals[proposalId];

        return proposal.votes.keys();
    }

    function getVoterResult(
        address voter
    ) public view isCounting returns (uint256) {
        uint256 proposalId = proposalCounter - 1;
        Proposal storage proposal = proposals[proposalId];

        return proposal.votes.get(voter);
    }

    function endProposal() public onlyOwner {
        uint256 proposalId = proposalCounter - 1;
        Proposal storage proposal = proposals[proposalId];

        proposal.status = Types.Status.ENDED;

        emit Ended(proposalId, proposal.endBlockHash);
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
}
