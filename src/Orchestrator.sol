pragma solidity ^0.8.20;

import {SixRPassport} from "./SixRPassport.sol";
import {SixRProposal} from "./SixRProposal.sol";
import {Types} from "./Types.sol";

contract Orchestrator {
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

    //TODO : Implement countVotes(), must unpause proposal contract
}
