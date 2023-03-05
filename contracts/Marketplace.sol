// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC1155/utils/ERC1155HolderUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC721/utils/ERC721HolderUpgradeable.sol";
import "./IERC20.sol";
import "./IERC721.sol";
import "./IERC1155.sol";

contract Marketplace is
    Initializable,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ERC1155HolderUpgradeable,
    ERC721HolderUpgradeable
{
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant MASTER_ROLE = keccak256("MASTER_ROLE");

    enum ContractType {
        Erc721,
        Erc1155
    }

    enum OrderStatus {
        Active,
        Canceled,
        Sold
    }

    struct Order {
        uint256 id;
        uint256 tokenId;
        uint256 initialAmount;
        uint256 currentAmount;
        uint256 price;
        address seller;
        address tokenAccepted;
        address contractAddress;
        OrderStatus status;
        ContractType contractType;
        bool sellByUnit;
    }

    // data come from safetransfer method
    struct TransferData {
        uint256 price;
        address tokenAccepted;
        bool sellByUnit;
    }

    event OrderAdded(uint256 indexed id, address indexed seller, Order order);

    event OrderCanceled(uint256 indexed id);

    event OrderBought(
        uint256 indexed id,
        address indexed buyer,
        uint256 quantity
    );

    mapping(address => bool) public approvedToken;

    /// @notice A mapping from order id to order data
    /// @dev This is a static, ever increasing list
    mapping(uint256 => Order) public orders;

    /// @notice The amount of orders
    uint256 public orderCount;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize() public initializer {
        __Pausable_init();
        __AccessControl_init();

        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        _grantRole(MASTER_ROLE, msg.sender);

        // address 0 for native token fantom
        approvedToken[address(0)] = true;
    }

    function addTokenAccepted(address tokenAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        approvedToken[tokenAddress] = true;
    }

    function removeTokenAccepted(address tokenAddress)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        approvedToken[tokenAddress] = false;
    }

    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    function onERC721Received(
        address,
        address from,
        uint256 tokenId,
        bytes memory data
    ) public virtual override returns (bytes4) {
        _sellNft(from, tokenId, 1, ContractType.Erc721, data);
        return this.onERC721Received.selector;
    }

    function onERC1155Received(
        address,
        address from,
        uint256 id,
        uint256 value,
        bytes memory data
    ) public virtual override returns (bytes4) {
        _sellNft(from, id, value, ContractType.Erc1155, data);
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
        //return this.onERC1155BatchReceived.selector;
    }

    function _sellNft(
        address from,
        uint256 id,
        uint256 amount,
        ContractType contractType,
        bytes memory data
    ) internal whenNotPaused {
        TransferData memory info = abi.decode(data, (TransferData));
        require(approvedToken[info.tokenAccepted], "Invalid token");

        orderCount++;

        Order memory orderInfo = Order(
            orderCount,
            id,
            amount,
            amount,
            info.price,
            from,
            info.tokenAccepted,
            _msgSender(),
            OrderStatus.Active,
            contractType,
            info.sellByUnit
        );
        orders[orderCount] = orderInfo;
        emit OrderAdded(orderCount, from, orderInfo);
    }

    function cancelOrder(uint256 orderId) public {
        Order storage order = orders[orderId];
        require(
            order.status == OrderStatus.Active,
            "Order is no longer available!"
        );
        require(
            hasRole(MASTER_ROLE, _msgSender()) || order.seller == _msgSender(),
            "Only the seller can cancel order"
        );
        require(order.currentAmount > 0, "Already sold");

        if (order.contractType == ContractType.Erc721) {
            IERC721(order.contractAddress).safeTransferFrom(
                address(this),
                order.seller,
                order.tokenId
            );
        } else if (order.contractType == ContractType.Erc1155) {
            IERC1155(order.contractAddress).safeTransferFrom(
                address(this),
                order.seller,
                order.tokenId,
                order.currentAmount,
                ""
            );
        }

        // Mark order
        order.currentAmount = 0;
        order.status = OrderStatus.Canceled;

        emit OrderCanceled(orderId);
    }

    function buyOrder(
        address buyer,
        uint256 orderId,
        uint256 price,
        uint256 amount
    ) public payable {
        Order storage order = orders[orderId];
        require(
            order.status == OrderStatus.Active,
            "Order is no longer available!"
        );
        require(amount > 0, "You can't buy nothing");
        require(order.currentAmount >= amount, "Not enough quantity");

        uint256 orderPrice = order.price;
        if (order.sellByUnit) {
            orderPrice = order.price * amount;
        }

        if (order.tokenAccepted == address(0)) {
            require(orderPrice == msg.value, "Buy price isn't equal to price!");
        } else {
            require(orderPrice == price, "Buy price isn't equal to price!");
        }

        //todo pay part

        if (order.contractType == ContractType.Erc721) {
            IERC721(order.contractAddress).safeTransferFrom(
                address(this),
                buyer,
                order.tokenId
            );
        } else if (order.contractType == ContractType.Erc1155) {
            IERC1155(order.contractAddress).safeTransferFrom(
                address(this),
                buyer,
                order.tokenId,
                amount,
                ""
            );
        }

        // Mark order
        uint256 currentAmount = order.currentAmount - amount;
        order.currentAmount = currentAmount;
        if (order.currentAmount == 0) {
            order.status = OrderStatus.Sold;
        }

        emit OrderBought(orderId, _msgSender(), amount);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC1155ReceiverUpgradeable, AccessControlUpgradeable)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
