// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.20;

import {ERC721} from "@openzeppelin/token/ERC721/ERC721.sol";
import "@openzeppelin/access/Ownable.sol";
import "@openzeppelin/utils/Strings.sol";
import "@openzeppelin/utils/Base64.sol";

/// @title 6th Republic — SixRPassport (SBT)
/// @notice Soulbound Token (ERC-721) used as a citizen identity passport in the 6R voting system.
/// @dev Non-transferable: transferFrom, approve, and setApprovalForAll all revert. Each address
///      can hold at most one passport. Also manages vote delegation state (representative mapping,
///      delegate power, and delegated mode). Contract state changes are pausable by the owner
///      during active voting periods.
contract SixRPassport is ERC721, Ownable {
    using Strings for uint256;

    /// @notice Emitted when a new passport is minted for a citizen.
    /// @param passportId The token ID of the newly minted passport.
    /// @param citizen The address of the citizen receiving the passport.
    /// @param pseudo Pseudo stored in the passport.
    event MintPassport(
        uint256 indexed passportId,
        address indexed citizen,
        string pseudo
    );

    /// @notice Emitted when a citizen enables delegated mode, making themselves available as a representative.
    /// @param citizen The address that enabled delegated mode.
    event DelegatedModeEnabled(address indexed citizen);

    /// @notice Emitted when a citizen disables delegated mode.
    /// @param citizen The address that disabled delegated mode.
    event DelegatedModeDisabled(address indexed citizen);

    /// @notice Emitted when a citizen delegates their vote to a representative.
    /// @param citizen The address delegating their vote.
    /// @param delegatedCitizen The address of the representative receiving the delegation.
    event DelegationTo(
        address indexed citizen,
        address indexed delegatedCitizen
    );

    /// @notice Emitted when a citizen revokes their vote delegation.
    /// @param citizen The address revoking the delegation.
    /// @param delegatedCitizen The address of the representative whose power is decremented.
    event RevokeDelegationTo(
        address indexed citizen,
        address indexed delegatedCitizen
    );

    /// @notice On-chain identity attributes stored per passport token.
    struct PassportAttributes {
        string pseudo;
        string nationality;
    }

    /// @dev Internal counter for token IDs. Incremented before each mint (starts at 1).
    uint256 private s_tokenIds;
    /// @dev Maps token ID to its on-chain passport attributes.
    mapping(uint256 => PassportAttributes) private s_tokenAttributes;

    // Delegation attributes
    /// @notice Maps a citizen's address to their chosen representative's address.
    ///         Set to address(0) when no delegation is active.
    mapping(address => address) public s_representatives;
    /// @notice Maps a delegate's address to the number of citizens who have delegated to them.
    ///         Each delegation increments this value; each revocation decrements it.
    mapping(address => uint256) public s_delegatePowers;
    /// @notice Indicates whether a citizen has enabled delegated mode (i.e., is accepting delegations).
    mapping(address => bool) public s_delegatedMode;

    /// @notice Whether the contract is currently paused. When true, all state-changing functions revert.
    /// @dev Set to true by the Orchestrator when a voting period starts; reset to false when it ends.
    bool public paused;

    /// @notice Restricts access to citizens who own a valid SixRPassport SBT.
    modifier ownsValidPassport() {
        require(
            hasPassport(msg.sender),
            "The citizen doesn't own a SixRPassport SBT"
        );
        _;
    }

    /// @notice Prevents state-changing calls while the contract is paused (during a voting period).
    modifier notPaused() {
        require(
            !paused,
            "The passport contract is paused for now, no changing state allowed."
        );
        _;
    }

    /// @notice Ensures the given address has enabled delegated mode.
    /// @param delegate The address to check.
    modifier isDelegate(address delegate) {
        require(
            s_delegatedMode[delegate] == true,
            "This citizen is not a delegate"
        );
        _;
    }

    /// @notice Ensures the given address has not enabled delegated mode.
    /// @param delegate The address to check.
    modifier isNotDelegate(address delegate) {
        require(
            s_delegatedMode[delegate] == false,
            "This citizen is a delegate"
        );
        _;
    }

    /// @notice Ensures the caller has an active vote delegation.
    modifier delegated() {
        require(
            s_representatives[msg.sender] != address(0),
            "Your vote is not delegated"
        );
        _;
    }

    /// @notice Ensures the caller has not yet delegated their vote.
    modifier notDelegated() {
        require(
            s_representatives[msg.sender] == address(0),
            "Your vote has already been delegated"
        );
        _;
    }

    /// @notice Initializes the ERC-721 token with name "6RVote" and symbol "6R".
    constructor() ERC721("6RVote", "6R") Ownable(msg.sender) {
        paused = false;
    }

    /// @notice Pauses or unpauses the contract.
    /// @dev Only callable by the owner (Orchestrator). Used to freeze delegation changes during voting.
    /// @param b True to pause, false to unpause.
    function pauseContract(bool b) public onlyOwner {
        paused = b;
    }

    /// @notice Returns whether the given address holds a valid SixRPassport.
    /// @param user The address to check.
    /// @return True if the address holds exactly one passport token.
    function hasPassport(address user) public view returns (bool) {
        return balanceOf(user) == 1;
    }

    // What if there is an error at the moment of a mint

    /// @notice Mints a new passport SBT to the specified citizen address.
    /// @dev Only callable by the owner (Orchestrator). Reverts if the recipient already holds a passport.
    ///      Token metadata is stored fully on-chain and exposed via tokenURI.
    /// @param to The address of the citizen receiving the passport.
    /// @param pseudo Pseudo.
    /// @param nationality Nationality (free-form string, format not enforced on-chain).
    /// @return The token ID of the newly minted passport.
    function safeMint(
        address to,
        string memory pseudo,
        string memory nationality
    ) public notPaused onlyOwner returns (uint256) {
        require(balanceOf(to) == 0, "This citizen has already a 6R passport");

        s_tokenIds++;

        //TODO : verification of correct data eg: nationality with Enum, date format)
        s_tokenAttributes[s_tokenIds] = PassportAttributes(pseudo, nationality);

        _safeMint(to, s_tokenIds);

        emit MintPassport(s_tokenIds, to, pseudo);

        return s_tokenIds;
    }

    /// @notice Enables delegated mode for the caller, making them available to receive vote delegations.
    /// @dev Caller must own a passport, not already be a delegate, and not have delegated their own vote.
    ///      Cannot be called while the contract is paused (voting period active).
    function enableDelegatedMode()
        public
        notPaused
        ownsValidPassport
        isNotDelegate(msg.sender)
        notDelegated
    {
        s_delegatedMode[msg.sender] = true;
        emit DelegatedModeEnabled(msg.sender);
    }

    /// @notice Disables delegated mode for the caller, preventing them from receiving new delegations.
    /// @dev Caller must own a passport and currently be in delegated mode.
    ///      Cannot be called while the contract is paused (voting period active).
    /// @custom:note Does not automatically revoke existing delegations from citizens who delegated to this address.
    function disableDelegatedMode()
        public
        notPaused
        ownsValidPassport
        isDelegate(msg.sender)
    {
        s_delegatedMode[msg.sender] = false;
        emit DelegatedModeDisabled(msg.sender);
    }

    /// @notice Delegates the caller's vote to a representative citizen.
    /// @dev Caller must own a passport, not be a delegate themselves, not have already delegated,
    ///      and the target must be in delegated mode. Increments the target's delegatePower by 1.
    ///      Cannot be called while the contract is paused (voting period active).
    /// @param to The address of the representative to delegate to.
    function delegateVoteTo(
        address to
    )
        public
        notPaused
        ownsValidPassport
        isNotDelegate(msg.sender)
        notDelegated
        isDelegate(to)
    {
        s_representatives[msg.sender] = to;
        s_delegatePowers[to]++;

        emit DelegationTo(msg.sender, to);
    }

    /// @notice Revokes the caller's active vote delegation.
    /// @dev Caller must own a passport and currently have an active delegation.
    ///      Resets the caller's representative to address(0) and decrements the former
    ///      representative's delegatePower by 1. Cannot be called while paused (voting period active).
    function revokeDelegation() public notPaused ownsValidPassport delegated {
        address revokedAddress = s_representatives[msg.sender];

        s_representatives[msg.sender] = address(0);
        s_delegatePowers[revokedAddress]--;

        emit RevokeDelegationTo(msg.sender, revokedAddress);
    }

    /// @notice Returns the on-chain Base64-encoded JSON metadata URI for a given passport token.
    /// @dev Metadata is fully on-chain (no external URI). The JSON includes all PassportAttributes
    ///      as ERC-721 trait attributes and a static IPFS image.
    /// @param tokenId The ID of the passport token.
    /// @return A data URI string in the format `data:application/json;base64,<encoded JSON>`.
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
                '{ "trait_type": "Pseudo", "value": "',
                pAttr.pseudo,
                '" },',
                '{ "trait_type": "Nationality", "value": "',
                pAttr.nationality,
                '" }',
                "],",
                '"image": "https://ipfs.io/ipfs/bafkreihaq34wyaut74plz32jqlicqzvfgawbb7l2b3p4phcpumgh4ictea"',
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

    /// @notice Blocked. SixRPassport tokens are soulbound and cannot be transferred.
    /// @dev Always reverts to enforce the SBT (Soulbound Token) property.
    function transferFrom(
        address, //from,
        address, //to,
        uint256 //tokenId
    ) public pure override {
        revert("SixRPassport SBT: Tokens are non-transferable");
    }

    /// @notice Blocked. SixRPassport tokens are soulbound and cannot be approved for transfer.
    /// @dev Always reverts to enforce the SBT property.
    function approve(address, uint256) public pure override {
        revert("SixRPassport SBT: Tokens are non-transferable");
    }

    /// @notice Blocked. SixRPassport tokens are soulbound and cannot be approved for transfer.
    /// @dev Always reverts to enforce the SBT property.
    function setApprovalForAll(address, bool) public pure override {
        revert("SixRPassport SBT: Tokens are non-transferable");
    }
}
