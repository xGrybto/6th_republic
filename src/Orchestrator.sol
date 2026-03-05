// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import "@openzeppelin/access/Ownable.sol";

import {SixRPassport} from "./SixRPassport.sol";
import {SixRProposal} from "./SixRProposal.sol";
import {Types} from "./Types.sol";

contract Orchestrator is Ownable {
    event ElectionResult(uint256 indexed proposalId, uint256 yes, uint256 no);

    SixRPassport public passport;
    SixRProposal public proposal;

    constructor() Ownable(msg.sender) {
        passport = new SixRPassport();
        proposal = new SixRProposal();
    }

    modifier ownsValidPassport() {
        require(
            passport.hasPassport(msg.sender),
            "The citizen doesn't own a SixRPassport SBT"
        );
        _;
    }

    modifier voteNotDelegated() {
        require(
            passport.s_representatives(msg.sender) == address(0), // != voting power, toujours 1 ou 0 => OK
            "Restricted : You have delegated your vote"
        );
        _;
    }

    //// Passport functionnalities /////
    // This could be also done without direct dependancy to the Orchestrator, but for what purpose ? Using passport in another context ?
    function mintPassport(
        address to,
        string memory p_name,
        string memory p_surname,
        string memory nationality,
        string memory birthDate,
        string memory birthPlace,
        string memory height
    ) public onlyOwner {
        passport.safeMint(
            to,
            p_name,
            p_surname,
            nationality,
            birthDate,
            birthPlace,
            height
        );
    }

    //// Proposal functionnalities ////

    function createProposal(
        string memory _title,
        string memory _description,
        Types.Category _category
    ) public ownsValidPassport returns (uint256) {
        uint256 id = proposal.create(
            msg.sender,
            _title,
            _description,
            _category
        );
        return id;
    }

    function startVoting(uint256 proposalId) public {
        proposal.startVoting(proposalId);
        passport.pauseContract(true);
    }

    function voteProposal(
        uint256 proposalId,
        Types.Vote vote
    ) public ownsValidPassport voteNotDelegated returns (bool) {
        bool voted = proposal.vote(proposalId, msg.sender, vote);

        if (!voted) {
            passport.pauseContract(false);
        }

        return voted;
    }

    //TODO : uniquement et une fois lorsque la proposition est terminée
    function countVotes(uint256 proposalId) public {
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

        emit ElectionResult(
            proposalId,
            result[uint256(Types.Vote.YES)],
            result[uint256(Types.Vote.NO)]
        );
    }
}
