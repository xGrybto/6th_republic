// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/utils/Strings.sol";
import "@openzeppelin/utils/Base64.sol";

contract SixRPassport is ERC721, Ownable {
    using Strings for uint256;

    event DelegationTo(
        address indexed citizen,
        address indexed delegatedCitizen
    );

    event RevokeDelegationTo(
        address indexed citizen,
        address indexed delegatedCitizen
    );

    struct PassportAttributes {
        string name;
        string surname;
        string nationality;
        string birthDate;
        string birthPlace;
        string height;
    }

    uint256 private s_tokenIds;
    mapping(uint256 => PassportAttributes) private s_tokenAttributes;

    //Delegation attributes
    mapping(address => address) public s_representatives;
    mapping(address => uint256) public s_votingPowers;

    bool public paused;

    modifier ownsValidPassport() {
        require(
            hasPassport(msg.sender),
            "The citizen doesn't own a SixRPassport SBT"
        );
        _;
    }

    modifier notPaused() {
        require(
            !paused,
            "The passport contract is paused for now, no changing state allowed."
        );
        _;
    }

    constructor() ERC721("6RVote", "6R") Ownable(msg.sender) {
        paused = false;
    }

    function pauseContract(bool b) public {
        paused = b;
    }

    function hasPassport(address user) public view returns (bool) {
        return balanceOf(user) == 1;
    }

    // What if there is an error at the moment of a mint
    function safeMint(
        address to,
        string memory p_name,
        string memory p_surname,
        string memory nationality,
        string memory birthDate,
        string memory birthPlace,
        string memory height
    ) public notPaused onlyOwner returns (uint256) {
        require(balanceOf(to) == 0, "This citizen has already a 6R passport");

        s_tokenIds++;
        s_votingPowers[to] = 1;

        //TODO : verification of correct data eg: nationality with Enum, date format)
        s_tokenAttributes[s_tokenIds] = PassportAttributes(
            p_name,
            p_surname,
            nationality,
            birthDate,
            birthPlace,
            height
        );

        _safeMint(to, s_tokenIds);

        return s_tokenIds;
    }

    function delegateVoteTo(address to) public notPaused ownsValidPassport {
        require(
            s_representatives[msg.sender] == address(0),
            "Your vote has already been delegated"
        );
        require(
            balanceOf(to) == 1,
            "This address is not eligible to receive vote"
        );

        s_representatives[msg.sender] = to;
        s_votingPowers[to]++;
        s_votingPowers[msg.sender]--;

        emit DelegationTo(msg.sender, to);
    }

    function revokeVote() public notPaused ownsValidPassport {
        address revokedAddress = s_representatives[msg.sender];
        require(revokedAddress != address(0), "Your vote is not delegated");

        s_representatives[msg.sender] = address(0);
        s_votingPowers[revokedAddress]--;
        s_votingPowers[msg.sender]++;

        emit RevokeDelegationTo(msg.sender, revokedAddress);
    }

    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        // require(s_tokenAttributes[tokenId], "Token does not exist");

        PassportAttributes memory pAttr = s_tokenAttributes[tokenId];

        // Génération du JSON
        string memory json = string(
            // aderyn-ignore-next-line(abi-encode-packed-hash-collision)
            abi.encodePacked(
                "{",
                '"name": "SixRPassport NFT #',
                tokenId.toString(),
                '",',
                '"description": "6R passport stored on-chain",',
                '"attributes": [',
                '{ "trait_type": "Name", "value": "',
                pAttr.name,
                '" },',
                '{ "trait_type": "Surname", "value": "',
                pAttr.surname,
                '" }',
                '{ "trait_type": "Nationality", "value": "',
                pAttr.nationality,
                '" }',
                '{ "trait_type": "BirthDate", "value": "',
                pAttr.birthDate,
                '" }',
                '{ "trait_type": "BirthPlace", "value": "',
                pAttr.birthPlace,
                '" }',
                '{ "trait_type": "Height", "value": "',
                pAttr.height,
                '" }',
                "],",
                '"image": "https://ipfs.io/ipfs/QmSVj85LTpa3nQSo2D7oq5XXKY9xQa4aSz5Rh2u2A5fLKf"',
                "}"
            )
        );

        // Encodage base64
        string memory encodedJson = Base64.encode(bytes(json));

        return
            string(
                // aderyn-ignore-next-line(abi-encode-packed-hash-collision)
                abi.encodePacked("data:application/json;base64,", encodedJson)
            );
    }

    function transferFrom(
        address, //from,
        address, //to,
        uint256 //tokenId
    ) public pure override {
        revert("SixRPassport SBT: Tokens are non-transferable");
    }

    function approve(address, uint256) public pure override {
        revert("SixRPassport SBT: Tokens are non-transferable");
    }

    function setApprovalForAll(address, bool) public pure override {
        revert("SixRPassport SBT: Tokens are non-transferable");
    }
}
