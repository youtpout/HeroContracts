// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721EnumerableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/ERC721BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/interfaces/IERC2981Upgradeable.sol";
import "@openzeppelin/contracts/interfaces/IERC2981.sol";

contract HeroPlayer is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    IERC2981Upgradeable
{
    struct StoreInfo {
        bool burn;
        uint16 position;
        address contractAddress;
        uint256 tokenId;
    }

    mapping(uint256 => mapping(uint16 => StoreInfo)) public linkNfts;
    mapping(address => bool) public _approvedMarketplaces;

    event stored(
        uint256 indexed tokenId,
        address indexed contractAddress,
        uint16 position,
        bool burned
    );

    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    CountersUpgradeable.Counter private _tokenIdCounter;

    string defaultUri = "https://hero.ovh/api/player/";

    address public bank;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __ERC721_init("Hero Player", "Hero");
        __ERC721Enumerable_init();
        __Pausable_init();
        __AccessControl_init();
        __ERC721Burnable_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);

        bank = msg.sender;
    }

    function _baseURI() internal view override returns (string memory) {
        return defaultUri;
    }

    function royaltyInfo(
        uint256, /*tokenId*/
        uint256 value
    ) external view override returns (address receiver, uint256 royaltyAmount) {
        // 10% royalties
        return (bank, (value * 10) / 100);
    }

    function addMarketAddress(address marketAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _approvedMarketplaces[marketAddress] = true;
    }

    function removeMarketAddress(address marketAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _approvedMarketplaces[marketAddress] = false;
    }

    function setDefaultUri(string calldata uri)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        defaultUri = uri;
    }

    function changeBank(address newBank) external onlyRole(DEFAULT_ADMIN_ROLE) {
        bank = newBank;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function safeMint(address to) public onlyRole(MINTER_ROLE) {
        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        _safeMint(to, tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId,
        uint256 batchSize
    )
        internal
        override(ERC721Upgradeable, ERC721EnumerableUpgradeable)
        whenNotPaused
    {
        super._beforeTokenTransfer(from, to, tokenId, batchSize);
    }

    // The following functions are overrides required by Solidity.

    function _burn(uint256 tokenId) internal override(ERC721Upgradeable) {
        super._burn(tokenId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        override(ERC721Upgradeable)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            AccessControlUpgradeable,
            IERC165Upgradeable
        )
        returns (bool)
    {
        return
            interfaceId == type(IERC2981).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function isApprovedForAll(address owner, address operator)
        public
        view
        virtual
        override(IERC721Upgradeable, ERC721Upgradeable)
        returns (bool)
    {
        // preapproved marketplace
        return
            _approvedMarketplaces[operator] ||
            super.isApprovedForAll(owner, operator);
    }
}
