// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';

contract FarmFinanceNFT is Ownable, ERC721, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemIds;
    address tokenBaseAddress;
    uint256[] priceLevels = [1000000000000000000000, 3000000000000000000000];
    event SeedBoxOpened(uint256 tokenId, address owner, uint256 timestamp);
    event MarketItemCreated(
        uint256 itemId,
        uint256 tokenId,
        uint256 price,
        address seller,
        uint256 timestamp
    );
    event MarketItemBought(
        uint256 itemId,
        uint256 tokenId,
        uint256 price,
        address seller,
        address buyer,
        uint256 timestamp
    );
    event MarketItemCanceled(
        uint256 itemId,
        uint256 tokenId,
        uint256 price,
        address seller,
        uint256 timestamp
    );
    //store a sell market item of a token
    struct MarketItem {
        uint256 itemId;
        uint256 tokenId;
        address seller;
        address buyer; //buyer
        uint256 price;
        bool sold;
        bool isCanceled;
    }
    //use itemIdToMarketItem[itemId] to get Item
    mapping(uint256 => MarketItem) private idToMarketItem;

    constructor(address _tokenBaseAddress) ERC721('Farm Finance NFT', 'FFN') {
        tokenBaseAddress = _tokenBaseAddress;
    }

    /**
     * get current gacha price
     */
    function getGachaPrice() public view returns (uint256[] memory) {
        return priceLevels;
    }

    /**
     * Set gacha price
     * @param level: we have 3 levels: 0,1,2
     * @param price: price want to set
     */
    function setGachaPrice(uint8 level, uint256 price) public onlyOwner {
        require(level < priceLevels.length, 'level invalid');
        priceLevels[level] = price;
    }

    /**
     * Open seed box is function for create a new token
     * @param level: we have 3 levels: 0,1
     */
    function openSeedBox(uint8 level) public nonReentrant {
        require(level < priceLevels.length);
        //need to approve first
        IERC20(tokenBaseAddress).transferFrom(
            msg.sender,
            address(this),
            priceLevels[level]
        );
        uint256 tokenId = _tokenIds.current();
        _mint(msg.sender, tokenId);
        _tokenIds.increment();
        emit SeedBoxOpened(tokenId, msg.sender, block.timestamp);
    }

    /**
     * Create market item to sell token
     * @param _tokenId: tokenId
     * @param _price: price want to set
     */
    function createMarketItem(uint256 _tokenId, uint256 _price)
        public
        nonReentrant
    {
        require(_price > 0);
        //need to approve first
        transferFrom(msg.sender, address(this), _tokenId);
        uint256 itemId = _itemIds.current();
        idToMarketItem[itemId] = MarketItem(
            itemId,
            _tokenId,
            msg.sender,
            address(0),
            _price,
            false,
            false
        );
        _itemIds.increment();
        emit MarketItemCreated(
            itemId,
            _tokenId,
            _price,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * Sender buy an item with its price
     * @param _itemId: id of market token
     */
    function buyMarketItem(uint256 _itemId) public nonReentrant {
        require(
            msg.sender != idToMarketItem[_itemId].seller,
            'asker must not be owner'
        );
        require(idToMarketItem[_itemId].sold == false, 'item has been sold');
        require(!idToMarketItem[_itemId].isCanceled, 'Item has been cancelled');
        idToMarketItem[_itemId].buyer = msg.sender;
        idToMarketItem[_itemId].sold = true;
        IERC20(tokenBaseAddress).transferFrom(
            msg.sender,
            idToMarketItem[_itemId].seller,
            idToMarketItem[_itemId].price
        );
        transferFrom(
            address(this),
            msg.sender,
            idToMarketItem[_itemId].tokenId
        );
        emit MarketItemBought(
            _itemId,
            idToMarketItem[_itemId].tokenId,
            idToMarketItem[_itemId].price,
            idToMarketItem[_itemId].seller,
            msg.sender,
            block.timestamp
        );
    }

    /**
     * Cancel an item, sender must be owner
     * @param _itemId: id of market token
     */
    function cancelMarketItem(uint256 _itemId) public nonReentrant {
        require(
            idToMarketItem[_itemId].seller == msg.sender,
            'sender must be the seller'
        );
        require(!idToMarketItem[_itemId].isCanceled, 'item has been cancelled');
        require(
            idToMarketItem[_itemId].buyer == address(0),
            'item has been sold'
        );
        transferFrom(
            address(this),
            msg.sender,
            idToMarketItem[_itemId].tokenId
        );
        idToMarketItem[_itemId].isCanceled = true;
        emit MarketItemCanceled(
            _itemId,
            idToMarketItem[_itemId].tokenId,
            idToMarketItem[_itemId].price,
            idToMarketItem[_itemId].seller,
            block.timestamp
        );
    }
}
