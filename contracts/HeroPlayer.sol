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
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "./IERC1155.sol";

contract HeroPlayer is
    Initializable,
    ERC721Upgradeable,
    ERC721EnumerableUpgradeable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ERC721BurnableUpgradeable,
    IERC2981Upgradeable,
    ERC1155HolderUpgradeable
{
    struct StoreInfo {
        bool burn;
        ContractType contractType;
        uint16 position;
        address contractAddress;
        uint256 tokenId;
        uint256 recipientTokenId;
    }

    enum ContractType {
        Erc721,
        Erc1155
    }

    mapping(uint256 => mapping(uint16 => StoreInfo)) public linkNfts;
    mapping(address => bool) public _approvedMarketplaces;
    mapping(address => bool) public _approvedLinker;

    // 5%
    uint256 public royalties = 500;

    event Linked(uint256 indexed recipientTokenId, StoreInfo indexed storeInfo);

    event Delinked(
        uint256 indexed recipientTokenId,
        StoreInfo indexed storeInfo
    );

    using CountersUpgradeable for CountersUpgradeable.Counter;

    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MASTER_ROLE = keccak256("MASTER_ROLE");

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
        __ERC1155Holder_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(MASTER_ROLE, msg.sender);

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
        return (bank, (value * royalties) / 10000);
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

    function addLinker(address linkerAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _approvedLinker[linkerAddress] = true;
    }

    function removeLinker(address linkerAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        _approvedLinker[linkerAddress] = false;
    }

    function setDefaultUri(string calldata uri)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        defaultUri = uri;
    }

    function setRoyalties(uint256 newRoyalty)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        royalties = newRoyalty;
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

    function onERC1155Received(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual override returns (bytes4) {
        require(value == 1, "Incorrect amount");
        _linkNft(operator, from, id, value, data);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address,
        address,
        uint256[] memory,
        uint256[] memory,
        bytes memory
    ) public virtual override returns (bytes4) {
        revert("Not implemented");
        return this.onERC1155BatchReceived.selector;
    }

    // link a nft to a hero
    function _linkNft(
        address operator,
        address from,
        uint256 id,
        uint256 value,
        bytes memory data
    ) internal {
        StoreInfo memory info = abi.decode(data, (StoreInfo));
        require(ownerOf(info.recipientTokenId) == from, "Not token owner");
        require(_msgSender() == info.contractAddress, "Incorrect sender");
        require(info.tokenId == id, "Incorrect tokenId");
        require(_approvedLinker[info.contractAddress], "Not approved linker");
        StoreInfo memory memoryInfo = linkNfts[info.recipientTokenId][
            info.position
        ];
        // we check if a nft is alreay linked at this position
        // we ignore burned nft (like skill)
        require(
            memoryInfo.tokenId == 0 || memoryInfo.burn,
            "Already a nft linked"
        );
        if (info.burn) {
            // we burn the nft to link it (like skill)
            IERC1155(info.contractAddress).burn(address(this), info.tokenId, 1);
        }

        linkNfts[info.recipientTokenId][info.position] = info;
        emit Linked(info.recipientTokenId, info);
    }

    // Remove nft linked to the hero, and transfer it to the owner
    function DelinkNft(uint256 tokenId, uint16 position) public {
        require(
            hasRole(MASTER_ROLE, _msgSender()) ||
                ownerOf(tokenId) == _msgSender(),
            "Not token owner"
        );
        StoreInfo memory memoryInfo = linkNfts[tokenId][position];
        require(!memoryInfo.burn, "Can't delink burned nft");
        if (memoryInfo.contractType == ContractType.Erc721) {
            IERC721Upgradeable(memoryInfo.contractAddress).safeTransferFrom(
                address(this),
                ownerOf(tokenId),
                memoryInfo.tokenId
            );
        } else if (memoryInfo.contractType == ContractType.Erc1155) {
            IERC1155(memoryInfo.contractAddress).safeTransferFrom(
                address(this),
                ownerOf(tokenId),
                memoryInfo.tokenId,
                1,
                ""
            );
        }
        delete linkNfts[tokenId][position];

        emit Delinked(tokenId, memoryInfo);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(
            ERC721Upgradeable,
            ERC721EnumerableUpgradeable,
            AccessControlUpgradeable,
            IERC165Upgradeable,
            ERC1155ReceiverUpgradeable
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
