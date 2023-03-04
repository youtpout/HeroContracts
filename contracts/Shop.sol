// // SPDX-License-Identifier: MIT
// // OpenZeppelin Contracts (last updated v4.5.0) (token/ERC721/presets/ERC721PresetMinterPauserAutoId.sol)

// pragma solidity ^0.8.4;

// import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Burnable.sol";
// import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
// import "@openzeppelin/contracts-upgradeable/access/AccessControlEnumerableUpgradeable.sol";
// import "@openzeppelin/contracts-upgradeable/utils/CountersUpgradeable.sol";
// import "./IItem.sol";
// import "./IPlayer.sol";
// import "./IMintable.sol";

// contract Shop is AccessControlEnumerableUpgradeable {
//     using CountersUpgradeable for CountersUpgradeable.Counter;

//     uint256 taxFee;

//     bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

//     IPlayer playerContract;
//     IItem itemContract;
//     IMintable tokenContract;

//     mapping(uint32 => uint128) public playersPrice;
//     mapping(uint32 => uint128) public itemsPrice;

//     enum OrderStatus {
//         Active,
//         Canceled,
//         Sold
//     }

//     enum TokenType {
//         item,
//         player
//     }

//     struct Order {
//         uint256 id;
//         uint256 tokenId;
//         uint256 price;
//         address seller;
//         address buyer;
//         OrderStatus status;
//         TokenType tokenType;
//     }

//     struct ItemPrice {
//         uint32 id;
//         uint128 price;
//         FightInfo.ItemInfo item;
//     }

//     struct PlayerPrice {
//         uint32 id;
//         uint128 price;
//         FightInfo.PlayerInfo player;
//     }

//     /// @notice A mapping from order id to order data
//     /// @dev This is a static, ever increasing list
//     mapping(uint256 => Order) public orders;

//     /// @notice The amount of orders
//     uint256 public orderCount;

//     /// @notice Mapping from owner to a list of owned auctions
//     mapping(address => uint256[]) public ownedOrders;

//     /// @notice Mapping from bought
//     mapping(address => uint256[]) public boughtOrders;

//     event ItemBought(uint32 indexed id, address indexed buyer);

//     event PlayerBought(uint32 indexed id, address indexed buyer);

//     event OrderAdded(uint256 indexed id, address indexed seller, Order order);

//     event OrderUpdated(uint256 indexed id, uint256 price);

//     event OrderCanceled(uint256 indexed id);

//     event OrderBought(uint256 indexed id, address indexed buyer);

//     function initialize(
//         IPlayer _playerContract,
//         IItem _itemContract,
//         IMintable _tokenContract
//     ) external initializer {
//         __AccessControlEnumerable_init();
//         _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
//         _grantRole(PAUSER_ROLE, msg.sender);

//         playerContract = _playerContract;
//         itemContract = _itemContract;
//         tokenContract = _tokenContract;

//         taxFee = 100;
//     }

//     function setTaxFee(uint256 amount) external onlyRole(DEFAULT_ADMIN_ROLE) {
//         require(amount < 300, "Tax exceed 30%");
//         taxFee = amount;
//     }

//     function setPlayerPrice(uint32 id, uint128 amount)
//         external
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         playersPrice[id] = amount;
//     }

//     function setItemPrice(uint32 id, uint128 amount)
//         external
//         onlyRole(DEFAULT_ADMIN_ROLE)
//     {
//         itemsPrice[id] = amount;
//     }

//     function buyCharacter(uint32 playerId) public {
//         uint128 playerPrice = playersPrice[playerId];
//         require(playerPrice > 0, "Can't be free");
//         tokenContract.burnToken(msg.sender, playerPrice);
//         playerContract.mint(msg.sender, playerId);
//         emit PlayerBought(playerId, msg.sender);
//     }

//     function buyItem(uint32 itemId) public {
//         uint128 itemPrice = itemsPrice[itemId];
//         require(itemPrice > 0, "Can't be free");
//         tokenContract.burnToken(msg.sender, itemPrice);
//         itemContract.mint(msg.sender, itemId);
//         emit ItemBought(itemId, msg.sender);
//     }

//     function buyCart(uint32[] memory playerIds, uint32[] memory itemIds)
//         external
//     {
//         if (playerIds.length > 0) {
//             for (uint256 index = 0; index < playerIds.length; index++) {
//                 buyCharacter(playerIds[index]);
//             }
//         }

//         if (itemIds.length > 0) {
//             for (uint256 index = 0; index < itemIds.length; index++) {
//                 buyItem(itemIds[index]);
//             }
//         }
//     }

//     function _calculateTax(uint256 amount) private view returns (uint256) {
//         return (amount * taxFee) / 1000;
//     }

//     function _getContract(TokenType tokenType) private view returns (IERC721) {
//         return
//             tokenType == TokenType.item
//                 ? IERC721(address(itemContract))
//                 : IERC721(address(playerContract));
//     }

//     /**
//      * @notice Creates an order, transfering into th
//      */
//     function createOrder(
//         uint256 tokenId,
//         TokenType tokenType,
//         uint256 price
//     ) external {
//         // the function return the address of the
//         IERC721 contractUsed = _getContract(tokenType);
//         require(
//             contractUsed.ownerOf(tokenId) == msg.sender,
//             "Not owner of token"
//         );
//         require(price > 0, "The price need to be more than 0");

//         // Transfer the brewery into the escrow contract
//         contractUsed.transferFrom(msg.sender, address(this), tokenId);

//         // Create the order
//         orders[orderCount] = Order({
//             id: orderCount,
//             status: OrderStatus.Active,
//             tokenId: tokenId,
//             seller: msg.sender,
//             buyer: address(0),
//             price: price,
//             tokenType: tokenType
//         });

//         ownedOrders[msg.sender].push(orderCount);

//         emit OrderAdded(orderCount, msg.sender, orders[orderCount]);

//         orderCount++;
//     }

//     /**
//      * @notice Updates the price of a listed orders
//      */
//     function updateOrder(uint256 orderId, uint256 price) external {
//         Order storage order = orders[orderId];
//         require(
//             order.status == OrderStatus.Active,
//             "Order is no longer available!"
//         );
//         require(order.seller == msg.sender, "Only the seller can update order");
//         require(price > 0, "The price need to be more than 0");
//         order.price = price;

//         emit OrderUpdated(orderId, price);
//     }

//     /**
//      * @notice Cancels a currently listed order, returning the item to the owner
//      */
//     function cancelOrder(uint256 orderId) external {
//         Order storage order = orders[orderId];
//         require(
//             order.status == OrderStatus.Active,
//             "Order is no longer available!"
//         );
//         require(order.seller == msg.sender, "Only the seller can cancel order");

//         IERC721 contractUsed = _getContract(order.tokenType);

//         // Transfer the brewery back to the seller
//         contractUsed.transferFrom(address(this), order.seller, order.tokenId);

//         // Mark order
//         order.status = OrderStatus.Canceled;

//         emit OrderCanceled(orderId);
//     }

//     /**
//      * @notice Purchases an active order
//      * @dev    `amount` is needed to ensure buyer isnt frontrun
//      */
//     function buyOrder(uint256 orderId) external {
//         Order storage order = orders[orderId];
//         require(
//             order.status == OrderStatus.Active,
//             "Order is no longer available!"
//         );

//         IERC721 contractUsed = _getContract(order.tokenType);

//         // Handle the transfer of payment
//         uint256 tax = _calculateTax(order.price);
//         uint256 amountTransfer = order.price - tax;
//         tokenContract.burnToken(msg.sender, tax);
//         require(
//             tokenContract.transferFrom(
//                 msg.sender,
//                 order.seller,
//                 amountTransfer
//             ),
//             "Amount transfer failed"
//         );

//         // Transfer the item to the buyer
//         contractUsed.transferFrom(address(this), msg.sender, order.tokenId);

//         // Remove the order from the active list
//         boughtOrders[msg.sender].push(orderId);

//         // Mark order
//         order.buyer = msg.sender;
//         order.status = OrderStatus.Sold;

//         emit OrderBought(orderId, msg.sender);
//     }

//     function fetchPageOrders(uint256 cursor, uint256 howMany)
//         external
//         view
//         returns (Order[] memory values, uint256 newCursor)
//     {
//         uint256 length = howMany;
//         if (length > orderCount - cursor) {
//             length = orderCount - cursor;
//         }

//         values = new Order[](length);
//         for (uint256 i = 0; i < length; i++) {
//             values[i] = orders[cursor + i];
//         }

//         return (values, cursor + length);
//     }

//     function getItemsPrice() external view returns (ItemPrice[] memory) {
//         FightInfo.ItemInfo[] memory infos = itemContract.getItems();
//         ItemPrice[] memory prices = new ItemPrice[](infos.length);
//         for (uint256 index = 0; index < infos.length; index++) {
//             FightInfo.ItemInfo memory info = infos[index];
//             prices[index] = ItemPrice(info.id, itemsPrice[info.id], info);
//         }
//         return prices;
//     }

//     function getPlayersPrice() external view returns (PlayerPrice[] memory) {
//         FightInfo.PlayerInfo[] memory infos = playerContract.getPlayers();
//         PlayerPrice[] memory prices = new PlayerPrice[](infos.length);
//         for (uint256 index = 0; index < infos.length; index++) {
//             FightInfo.PlayerInfo memory info = infos[index];
//             prices[index] = PlayerPrice(info.playerId, playersPrice[info.playerId], info);
//         }
//         return prices;
//     }
// }
