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

    event Created(
        uint256 indexed proposalId,
        address indexed creator,
        string title
    );

    event Voted(uint256 indexed proposalId, address indexed voter);

    event Ended(uint256 indexed proposalId, bytes32 indexed _blockhash);

    struct Proposal {
        string title;
        string description;
        Types.Category category;
        address creator;
        uint256 creationTime;
        Types.Status status;
        EnumerableMap.AddressToUintMap votes; // address => Vote
        bytes32 endBlockHash;
    }

    uint256 public proposalCounter;
    mapping(uint256 => Proposal) proposals;

    modifier isEnded() {
        require(
            proposals[proposalCounter - 1].status == Types.Status.ENDED,
            "Current proposal is not yet voted"
        );
        _;
    }

    modifier isOngoing() {
        require(
            proposals[proposalCounter - 1].status == Types.Status.ONGOING,
            "Proposal voted, vote is not accepted anymore"
        );
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
        proposal.status = Types.Status.ONGOING;

        emit Created(proposalId, sender, _title);

        proposalCounter++;

        return proposalId;
    }

    function vote(
        address sender,
        Types.Vote _vote
    ) public onlyOwner isOngoing returns (bool) {
        //TODO Checks :
        // - que le citoyen est un passeport valide (ownsValidPassport)
        // - que le vote ne soit pas délégué (précaution)
        // - la personne n'a pas déjà voté
        // - le vote soit ouvert
        uint256 proposalId = proposalCounter - 1;

        Proposal storage proposal = proposals[proposalId];
        require(!proposal.votes.contains(sender), "You have already voted");
        if (proposal.creationTime + VOTING_PERIOD < block.timestamp) {
            end(proposal);
            return false;
        } else {
            proposal.votes.set(sender, uint256(_vote));
            emit Voted(proposalId, sender);
            return true;
        }
    }

    function end(Proposal storage p) private {
        p.status = Types.Status.ENDED;
        p.endBlockHash = blockhash(block.number);
        emit Ended(proposalCounter - 1, p.endBlockHash);
    }

    //TODO : Implement countVotes()

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
