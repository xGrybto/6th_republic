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
        uint256 imageIndex;
    }

    /// @dev Internal counter for token IDs. Incremented before each mint (starts at 1).
    uint256 private s_tokenIds;
    /// @dev Maps token ID to its on-chain passport attributes.
    mapping(uint256 => PassportAttributes) private s_tokenAttributes;
    /// @dev Maps a citizen's address to their passport token ID. Set at mint time.
    mapping(address => uint256) private s_tokenIdByAddress;

    /// @dev Base IPFS URI for passport images (e.g. "ipfs://QmBaseHash/").
    ///      Images are named 1.svg, 2.svg, ... and selected pseudo-randomly at mint.
    string private s_baseImageURI;
    /// @dev Color names indexed in the same order as the images (1.svg → index 0, 2.svg → index 1, ...).
    string[] private s_imageColors;

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
    constructor() ERC721("6R Passport", "6R") Ownable(msg.sender) {
        paused = false;
    }

    /// @notice Pauses or unpauses the contract.
    /// @dev Only callable by the owner (Orchestrator). Used to freeze delegation changes during voting.
    /// @param b True to pause, false to unpause.
    function pauseDelegation(bool b) public onlyOwner {
        paused = b;
    }

    /// @notice Returns whether the given address holds a valid SixRPassport.
    /// @param user The address to check.
    /// @return True if the address holds exactly one passport token.
    function hasPassport(address user) public view returns (bool) {
        return balanceOf(user) == 1;
    }

    // What if there is an error at the moment of a mint

    /// @notice Validates a string for safe on-chain JSON embedding.
    /// @dev Reverts if the string is empty, exceeds maxLen bytes, or contains characters
    ///      that would break JSON structure: `"` (0x22), `\` (0x5C), or ASCII control
    ///      characters (< 0x20 or 0x7F).
    /// @param str The string to validate.
    /// @param maxLen Maximum allowed byte length.
    function _validateString(string memory str, uint256 maxLen) private pure {
        bytes memory b = bytes(str);
        require(b.length > 0, "String must not be empty");
        require(b.length <= maxLen, "String exceeds maximum length");
        bool valid = true;
        for (uint256 i = 0; i < b.length; i++) {
            bytes1 c = b[i];
            if (c == 0x22 || c == 0x5C || uint8(c) < 0x20 || c == 0x7F) {
                valid = false;
                break;
            }
        }
        require(valid, "String contains invalid characters");
    }

    /// @notice Sets the base IPFS URI and color list for passport images.
    /// @dev Only callable by the owner. Must be called before the first mint.
    ///      Images must be named 1.svg, 2.svg, ... on IPFS.
    ///      The colors array must match the image count (index 0 → 1.svg, index 1 → 2.svg, ...).
    /// @param baseImageURI Base IPFS URI ending with "/" (e.g. "ipfs://QmBaseHash/").
    /// @param imageColors Array of color names in the same order as the images.
    function setImageConfig(
        string memory baseImageURI,
        string[] memory imageColors
    ) public onlyOwner {
        require(imageColors.length > 0, "At least one image required");
        s_baseImageURI = baseImageURI;
        s_imageColors = imageColors;
    }

    /// @notice Mints a new passport SBT to the specified citizen address.
    /// @dev Only callable by the owner (Orchestrator). Reverts if the recipient already holds a passport
    ///      or if image config has not been set. Pseudo-randomly selects an image from the IPFS folder
    ///      using block.timestamp, recipient address, and token ID as entropy.
    ///      Pseudo and nationality are validated to prevent JSON injection in tokenURI.
    /// @param to The address of the citizen receiving the passport.
    /// @param pseudo Pseudo (max 32 characters, no `"` or `\` or control characters).
    /// @param nationality Nationality (max 50 characters, same restrictions).
    /// @return The token ID of the newly minted passport.
    function safeMint(
        address to,
        string memory pseudo,
        string memory nationality
    ) public onlyOwner returns (uint256) {
        require(balanceOf(to) == 0, "This citizen has already a 6R passport");
        require(s_imageColors.length > 0, "Image config not set");

        _validateString(pseudo, 32);
        _validateString(nationality, 50);

        s_tokenIds++;

        uint256 imageIndex = uint256(
            // aderyn-ignore-next-line(weak-randomness)
            keccak256(abi.encodePacked(block.timestamp, to, s_tokenIds))
        ) % s_imageColors.length;

        s_tokenAttributes[s_tokenIds] = PassportAttributes(
            pseudo,
            nationality,
            imageIndex
        );
        s_tokenIdByAddress[to] = s_tokenIds;

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

    /// @notice Returns the passport attributes of a citizen from their address.
    /// @param citizen The address of the citizen.
    /// @return pseudo The citizen's pseudo.
    /// @return nationality The citizen's nationality.
    /// @return color The color name associated with the citizen's passport image.
    function getPassportAttributes(
        address citizen
    )
        external
        view
        returns (
            string memory pseudo,
            string memory nationality,
            string memory color
        )
    {
        require(hasPassport(citizen), "This citizen has no passport");
        PassportAttributes memory attrs = s_tokenAttributes[
            s_tokenIdByAddress[citizen]
        ];
        return (
            attrs.pseudo,
            attrs.nationality,
            s_imageColors[attrs.imageIndex]
        );
    }

    /// @notice Returns the full tokenURI (Base64 JSON metadata) of a citizen from their address.
    /// @param citizen The address of the citizen.
    /// @return The tokenURI string in the format `data:application/json;base64,<encoded JSON>`.
    function getTokenURI(
        address citizen
    ) external view returns (string memory) {
        require(hasPassport(citizen), "This citizen has no passport");
        return tokenURI(s_tokenIdByAddress[citizen]);
    }

    /// @notice Returns the on-chain Base64-encoded JSON metadata URI for a given passport token.
    /// @dev JSON is generated fully on-chain and follows the OpenSea metadata standard.
    ///      The image field points to the IPFS folder set via setImageConfig, using the
    ///      pseudo-randomly assigned imageIndex stored at mint time.
    /// @param tokenId The ID of the passport token.
    /// @return A data URI string in the format `data:application/json;base64,<encoded JSON>`.
    function tokenURI(
        uint256 tokenId
    ) public view override returns (string memory) {
        PassportAttributes memory pAttr = s_tokenAttributes[tokenId];

        string memory json = string(
            // aderyn-ignore-next-line(abi-encode-packed-hash-collision)
            abi.encodePacked(
                '{"name": "6R Passport SBT #',
                tokenId.toString(),
                '",',
                '"description": "6R passport stored on-chain",',
                '"image": "',
                s_baseImageURI,
                pAttr.imageIndex.toString(),
                '.svg",',
                '"attributes": [',
                '{"trait_type": "Pseudo", "value": "',
                pAttr.pseudo,
                '"},',
                '{"trait_type": "Nationality", "value": "',
                pAttr.nationality,
                '"},',
                '{"trait_type": "Color", "value": "',
                s_imageColors[pAttr.imageIndex],
                '"}',
                "]}"
            )
        );

        return
            string(
                // aderyn-ignore-next-line(abi-encode-packed-hash-collision)
                abi.encodePacked(
                    "data:application/json;base64,",
                    Base64.encode(bytes(json))
                )
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
