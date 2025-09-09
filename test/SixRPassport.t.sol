// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {SixRPassport} from "../src/SixRPassport.sol";
import {Test, console} from "forge-std/Test.sol";

contract SixRPassportTest is Test {
    SixRPassport private sixRContract;

    address owner = address(0x010);
    address citizen_1 = address(0x01);
    address citizen_2 = address(0x02);
    address citizen_3 = address(0x03);

    function setUp() public {
        vm.prank(owner);
        sixRContract = new SixRPassport();
    }

    function setUpC1() public {
        vm.prank(owner);
        sixRContract.safeMint(
            citizen_1,
            "Marc",
            "JOTE",
            "Francais",
            "01/05/2000",
            "Lille",
            "2m05"
        );
    }

    function setUpC2() public {
        vm.prank(owner);
        sixRContract.safeMint(
            citizen_2,
            "Jose",
            "Cuelva",
            "Francais",
            "27/09/1985",
            "Biarritz",
            "1m71"
        );
    }

    function setUpC3() public {
        vm.prank(owner);
        sixRContract.safeMint(
            citizen_3,
            "Eva",
            "Mava",
            "Francaise",
            "01/11/2007",
            "Biarritz",
            "1m71"
        );
    }

    function test_mintPassport() public {
        assertEq(sixRContract.balanceOf(citizen_1), 0);
        vm.prank(owner);
        sixRContract.safeMint(
            citizen_1,
            "Marc",
            "JOTE",
            "Francais",
            "01/05/1000",
            "Lille",
            "2m05"
        );
        assertEq(sixRContract.balanceOf(citizen_1), 1);
        assertEq(sixRContract.ownerOf(1), citizen_1);
    }

    function test_cannotHaveMoreThanOnePassport() public {
        vm.startPrank(owner);
        sixRContract.safeMint(
            citizen_1,
            "Marc",
            "JOTE",
            "Francais",
            "01/05/2000",
            "Lille",
            "2m05"
        );
        vm.expectRevert("This citizen has already a 6R passport");
        sixRContract.safeMint(
            citizen_1,
            "Marc",
            "JOTE",
            "Francais",
            "01/05/2000",
            "Lille",
            "2m05"
        );
    }

    function test_citizenHasNoPassportAtInit() public view {
        assertEq(sixRContract.balanceOf(citizen_1), 0);
    }

    function test_cannotTransferPassportInAnyWay() public {
        setUpC1();

        // ctz 1 wants to transfer passport to ctz 2
        vm.startPrank(citizen_1);
        vm.expectRevert("SixRPassport SBT: Tokens are non-transferable");
        sixRContract.approve(address(this), 1);
        vm.expectRevert("SixRPassport SBT: Tokens are non-transferable");
        sixRContract.setApprovalForAll(address(this), true);
        vm.expectRevert("SixRPassport SBT: Tokens are non-transferable");
        sixRContract.transferFrom(citizen_1, citizen_2, 1);
        vm.expectRevert("SixRPassport SBT: Tokens are non-transferable");
        sixRContract.safeTransferFrom(citizen_1, citizen_2, 1);
        vm.expectRevert("SixRPassport SBT: Tokens are non-transferable");
        sixRContract.safeTransferFrom(citizen_1, citizen_2, 1, "");
        vm.stopPrank();
    }

    function test_delegateVoteToNonPassportOwner() public {
        setUpC1();

        vm.prank(citizen_1);
        vm.expectRevert("This address is not eligible to receive vote");
        sixRContract.delegateVoteTo(citizen_2);
    }

    function test_delegateVoteToPassportOwner() public {
        setUpC1();
        setUpC2();

        vm.prank(citizen_1);
        sixRContract.delegateVoteTo(citizen_2);

        assertEq(sixRContract.s_votingPowers(citizen_2), 2);
        assertEq(sixRContract.s_votingPowers(citizen_1), 0);
    }

    function test_revokeBeforeDelegation() public {
        setUpC1();

        vm.prank(citizen_1);
        vm.expectRevert("Your vote is not delegated");
        sixRContract.revokeVote();
    }

    function test_revokeAfterDelegation() public {
        setUpC1();
        setUpC2();

        vm.startPrank(citizen_1);
        sixRContract.delegateVoteTo(citizen_2);
        sixRContract.revokeVote();

        assertEq(sixRContract.s_votingPowers(citizen_2), 1);
        assertEq(sixRContract.s_votingPowers(citizen_1), 1);
        vm.stopPrank();
    }

    function test_DelegateMultipleTime() public {
        setUpC1();
        setUpC2();
        setUpC3();

        vm.startPrank(citizen_1);
        sixRContract.delegateVoteTo(citizen_2);
        vm.expectRevert("Your vote has already been delegated");
        sixRContract.delegateVoteTo(citizen_3);
        vm.stopPrank();
    }

    function test_tokenURI() public {
        setUpC1();
        string memory tokenURI = sixRContract.tokenURI(1);

        assertEq(
            bytes(tokenURI),
            bytes(
                "data:application/json;base64,eyJuYW1lIjogIlNpeFJQYXNzcG9ydCBORlQgIzEiLCJkZXNjcmlwdGlvbiI6ICI2UiBwYXNzcG9ydCBzdG9yZWQgb24tY2hhaW4iLCJhdHRyaWJ1dGVzIjogW3sgInRyYWl0X3R5cGUiOiAiTmFtZSIsICJ2YWx1ZSI6ICJNYXJjIiB9LHsgInRyYWl0X3R5cGUiOiAiU3VybmFtZSIsICJ2YWx1ZSI6ICJKT1RFIiB9eyAidHJhaXRfdHlwZSI6ICJOYXRpb25hbGl0eSIsICJ2YWx1ZSI6ICJGcmFuY2FpcyIgfXsgInRyYWl0X3R5cGUiOiAiQmlydGhEYXRlIiwgInZhbHVlIjogIjAxLzA1LzIwMDAiIH17ICJ0cmFpdF90eXBlIjogIkJpcnRoUGxhY2UiLCAidmFsdWUiOiAiTGlsbGUiIH17ICJ0cmFpdF90eXBlIjogIkhlaWdodCIsICJ2YWx1ZSI6ICIybTA1IiB9XSwiaW1hZ2UiOiAiaHR0cHM6Ly9pcGZzLmlvL2lwZnMvUW1TVmo4NUxUcGEzblFTbzJEN29xNVhYS1k5eFFhNGFTejVSaDJ1MkE1ZkxLZiJ9"
            )
        );
    }
}
