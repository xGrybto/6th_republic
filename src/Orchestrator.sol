pragma solidity ^0.8.20;

import {SixRPassport} from "./SixRPassport.sol";
import {SixRProposal} from "./SixRProposal.sol";
import {Types} from "./Types.sol";

contract Orchestrator {
    event ElectionVoted(uint256 yes, uint256 no, uint256 abstention);

    event ElectionRefused(uint256 yes, uint256 no, uint256 abstention);

    SixRPassport public passport;
    SixRProposal public proposal;

    constructor() {
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
        passport.pauseContract(true);
        return id;
    }

    function voteProposal(
        Types.Vote vote
    ) public ownsValidPassport voteNotDelegated returns (bool) {
        bool isVoted = proposal.vote(msg.sender, vote);

        if (!isVoted) {
            // The voting period of the proposal is over
            //TODO : Put proposal contract on standby
            passport.pauseContract(false);
        }

        return isVoted;
    }

    function countVotes() public {
        address[] memory voters = proposal.getVoters();

        uint256[3] memory result;

        for (uint index = 0; index < voters.length; index++) {
            address voter = voters[index];
            result[proposal.getVoterResult(voter)] += passport.s_votingPowers(
                voter
            );
        }

        if (result[uint(Types.Vote.YES)] > result[uint(Types.Vote.NO)]) {
            emit ElectionVoted(
                //proposal ID
                result[uint(Types.Vote.YES)],
                result[uint(Types.Vote.NO)],
                result[uint(Types.Vote.NULL)]
            );
        } else {
            emit ElectionRefused(
                //proposal ID
                result[uint(Types.Vote.YES)],
                result[uint(Types.Vote.NO)],
                result[uint(Types.Vote.NULL)]
            );
        }

        proposal.endProposal();
    }
}
