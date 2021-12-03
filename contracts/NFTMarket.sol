// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import './interface/INFT.sol';

contract NFTMarket is ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _itemIds;
    Counters.Counter private _itemsSold;
    Counters.Counter private _itemsLent;
    Counters.Counter private _isCancelLent;
    Counters.Counter private _itemLendIds;
    Counters.Counter private _itemsCancelled;
    address payable owner;
    uint256 listingPrice = 0.0025 ether;
    //address of erc721 nft contract
    //address nftContract;

    event MarketItemCreated(
        address nftContract,
        uint256 itemId,
        uint256 tokenId,
        address seller,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 endBlock
    );

    event LendItemCreated(
        address nftContract,
        uint256 itemId,
        uint256 tokenId,
        address lender,
        uint256 priceLend,
        uint256 lendBlockDuration
    );

    struct LendHistory {
        uint256 id;
        uint256 itemMarketId;
        uint256 tokenId;
        address payable lender;
        address payable borrower;
        uint256 priceLend;
        uint256 blockNumber;
    }

    event ItemBorrow(
        address nftContract,
        uint256 itemId,
        uint256 tokenId,
        address sender
    );

    event LendCanceled(
        address nftContract,
        uint256 itemId,
        uint256 tokenId,
        address lender
    );

    event OfferPlaced(
        address nftContract,
        uint256 itemId,
        uint256 tokenId,
        uint256 offerId,
        address asker,
        uint256 amount,
        uint256 blockTime
    );
    event RewardClaimed(
        address nftContract,
        uint256 itemId,
        uint256 tokenId,
        uint256 offerId,
        address sender,
        uint256 blockTime,
        uint256 currentPrice
    );
    event ItemCanceled(
        address nftContract,
        uint256 itemId,
        uint256 tokenId,
        address sender
    );
    event ItemBuyDirectly(
        address nftContract,
        uint256 itemId,
        uint256 tokenId,
        address sender,
        uint256 currentPrice
    );
    event RetrieveItem(
        address nftContract,
        uint256 itemId,
        uint256 tokenId,
        uint256 blockTime,
        uint256 timestamp,
        address sender
    );
    //store offer of an item
    struct Offer {
        uint256 offerId;
        address asker;
        uint256 amount;
        bool refundable;
        uint256 blockTime;
    }
    //store a sell market item of a token
    struct MarketItem {
        address nftContract;
        uint256 itemId;
        uint256 tokenId;
        address payable seller;
        address payable buyer; //buyer
        uint256 minPrice;
        uint256 maxPrice;
        uint256 currentPrice;
        uint256 endBlock;
        bool sold;
        bool isCanceled;
        Counters.Counter offerCount;
    }

    struct LendItem {
        address nftContract;
        uint256 itemId;
        uint256 tokenId;
        address payable lender;
        address payable borrower;
        uint256 priceLend;
        bool lent;
        bool paid;
        bool isCanceled;
        uint256 lendBlockDuration;
    }

    struct SellHistory {
        uint256 id;
        uint256 itemMarketId;
        uint256 tokenId;
        address payable seller;
        address payable buyer;
        uint256 price;
        uint256 blockNumber;
    }

    //use itemIdToMarketItem[itemId] to get Item
    mapping(uint256 => MarketItem) private idToMarketItem;
    //use itemIdToOffer[itemId][offerId] to get offer
    mapping(uint256 => mapping(uint256 => Offer)) private itemIdToOffer;
    //use tokenSellCount[tokenId] to get how many time token was sold
    mapping(uint256 => Counters.Counter) private tokenSellCount;
    //use tokenIdToSellHistory[tokenId][sellHistoryId] to get sell history
    mapping(uint256 => mapping(uint256 => SellHistory))
        private tokenIdToSellHistory;
    // use lendHistory
    mapping(uint256 => mapping(uint256 => LendHistory))
        private tokenIdToLendHistory;
    mapping(uint256 => Counters.Counter) private tokenLendCount;

    mapping(uint256 => LendItem) private lendItems;

    constructor() {
        owner = payable(msg.sender);
    }

    /* Returns the listing price of the contract */
    function getListingPrice() public view returns (uint256) {
        return listingPrice;
    }

    /* Returns the market item by item id */
    function getMarketItem(uint256 itemId)
        public
        view
        returns (MarketItem memory)
    {
        return idToMarketItem[itemId];
    }

    /// @notice Make an market item for sell token. Token must be approved first
    /// @param tokenId id of token
    /// @param minPrice minimum price to make offer
    /// @param maxPrice maximum price to make offer
    /// @param endBlock block that item stops receiving offer
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 minPrice,
        uint256 maxPrice,
        uint256 endBlock
    ) public payable nonReentrant {
        require(
            msg.value == listingPrice,
            'Order fee must be equal to listing price'
        );
        require(
            minPrice <= maxPrice,
            'max price must be greater than min price'
        );
        require(minPrice > 0);
        uint256 itemId = _itemIds.current();
        Counters.Counter memory offercount;
        idToMarketItem[itemId] = MarketItem(
            nftContract,
            itemId,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            minPrice,
            maxPrice,
            0,
            endBlock,
            false,
            false,
            offercount
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        _itemIds.increment();
        emit MarketItemCreated(
            nftContract,
            itemId,
            tokenId,
            msg.sender,
            minPrice,
            maxPrice,
            endBlock
        );
    }

    /// @notice user not owner make offer. set the value want to make offer
    /// @param itemId id of market item
    function makeOffer(uint256 itemId) public payable nonReentrant {
        require(
            msg.sender != idToMarketItem[itemId].seller,
            'asker must not be owner'
        );
        require(idToMarketItem[itemId].sold == false, 'item has been sold');
        require(
            idToMarketItem[itemId].endBlock >= block.number,
            'Item has been expired'
        );
        require(!idToMarketItem[itemId].isCanceled, 'Item has been cancelled');
        require(
            msg.value >= idToMarketItem[itemId].minPrice,
            'Offer must greater than min price'
        );
        require(
            msg.value > idToMarketItem[itemId].currentPrice,
            'Offer must greater than current price'
        );
        require(
            msg.value < idToMarketItem[itemId].maxPrice,
            'Offer must less than max price'
        );
        //payable(address(this)).transfer(msg.value);
        uint256 offerId = idToMarketItem[itemId].offerCount.current();
        Offer memory newOffer;
        newOffer.offerId = offerId;
        newOffer.asker = msg.sender;
        newOffer.amount = msg.value;
        newOffer.refundable = true;
        newOffer.blockTime = block.number;
        itemIdToOffer[itemId][offerId] = newOffer;
        idToMarketItem[itemId].currentPrice = msg.value;
        // refund lower offer
        if (offerId > 0 && itemIdToOffer[itemId][offerId - 1].refundable) {
            uint256 amount = itemIdToOffer[itemId][offerId].amount;
            itemIdToOffer[itemId][offerId - 1].refundable = false;
            payable(itemIdToOffer[itemId][offerId - 1].asker).transfer(amount);
        }
        idToMarketItem[itemId].offerCount.increment();
        emit OfferPlaced(
            idToMarketItem[itemId].nftContract,
            itemId,
            idToMarketItem[itemId].tokenId,
            offerId,
            msg.sender,
            msg.value,
            block.number
        );
    }

    /// @notice Directly buy an token from market item. value must be set by item maximum price
    /// @param itemId id of market item
    function buyDirectly(uint256 itemId) public payable nonReentrant {
        uint256 currentBlock = block.number;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        require(
            msg.sender != idToMarketItem[itemId].seller,
            'asker must not be owner'
        );

        require(idToMarketItem[itemId].sold == false, 'item has been sold');
        require(!idToMarketItem[itemId].isCanceled, 'Item has been cancelled');
        require(
            idToMarketItem[itemId].maxPrice == msg.value,
            'Price must equal to max price to buy directly'
        );

        idToMarketItem[itemId].buyer = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        idToMarketItem[itemId].currentPrice = msg.value;
        uint256 newSellHistoryId = tokenSellCount[tokenId].current();
        _itemsSold.increment();
        SellHistory memory sellHistory = SellHistory(
            newSellHistoryId,
            itemId,
            tokenId,
            idToMarketItem[itemId].seller,
            idToMarketItem[itemId].buyer,
            msg.value,
            currentBlock
        );
        tokenIdToSellHistory[tokenId][newSellHistoryId] = sellHistory;
        tokenSellCount[tokenId].increment();
        idToMarketItem[itemId].seller.transfer(msg.value);
        IERC721(idToMarketItem[itemId].nftContract).transferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        payable(owner).transfer(listingPrice);
        //idToMarketItem[itemId].seller.transfer(listingPrice);
        emit ItemBuyDirectly(
            idToMarketItem[itemId].nftContract,
            itemId,
            tokenId,
            msg.sender,
            idToMarketItem[itemId].currentPrice
        );
    }

    /// @notice user claim token if won the audit
    /// @param itemId id of market item
    /// @param offerId id of offer that user won
    function claimReward(uint256 itemId, uint256 offerId)
        public
        payable
        nonReentrant
    {
        uint256 currentBlock = block.number;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        uint256 amount = itemIdToOffer[itemId][offerId].amount;
        require(
            msg.sender != idToMarketItem[itemId].seller,
            'asker must not be owner'
        );
        require(idToMarketItem[itemId].sold == false, 'item has been sold');
        require(
            idToMarketItem[itemId].endBlock < currentBlock,
            "item hasn't exceeded claim stage"
        );
        require(!idToMarketItem[itemId].isCanceled, 'item has been cancelled');
        require(
            itemIdToOffer[itemId][offerId].asker == msg.sender,
            'sender is not offer owner'
        );
        require(
            itemIdToOffer[itemId][offerId].refundable,
            'offer has been refunded'
        );
        require(
            amount == idToMarketItem[itemId].currentPrice,
            'sender is not item winner'
        );

        idToMarketItem[itemId].buyer = payable(msg.sender);
        idToMarketItem[itemId].sold = true;
        itemIdToOffer[itemId][offerId].refundable == false;
        uint256 newSellHistoryId = tokenSellCount[tokenId].current();
        SellHistory memory sellHistory = SellHistory(
            newSellHistoryId,
            itemId,
            tokenId,
            idToMarketItem[itemId].seller,
            payable(msg.sender),
            amount,
            block.number
        );
        tokenIdToSellHistory[tokenId][newSellHistoryId] = sellHistory;
        _itemsSold.increment();
        tokenSellCount[tokenId].increment();
        idToMarketItem[itemId].seller.transfer(amount);
        IERC721(idToMarketItem[itemId].nftContract).transferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        payable(owner).transfer(listingPrice);
        emit RewardClaimed(
            idToMarketItem[itemId].nftContract,
            itemId,
            tokenId,
            offerId,
            msg.sender,
            block.number,
            amount
        );
    }

    /// @notice market item owner cancel and refund nft
    /// @param itemId id of market item
    function cancelMarketItemAuction(uint256 itemId) public nonReentrant {
        require(
            idToMarketItem[itemId].seller == msg.sender,
            'sender must be seller'
        );
        require(!idToMarketItem[itemId].isCanceled, 'item has been cancelled');
        require(
            idToMarketItem[itemId].offerCount.current() == 0,
            'there are offers placed on this market item'
        );
        require(
            idToMarketItem[itemId].buyer == address(0),
            'item has been sold'
        );
        IERC721(idToMarketItem[itemId].nftContract).transferFrom(
            address(this),
            idToMarketItem[itemId].seller,
            idToMarketItem[itemId].tokenId
        );
        idToMarketItem[itemId].isCanceled = true;
        idToMarketItem[itemId].seller.transfer(listingPrice);
        _itemsCancelled.increment();
        emit ItemCanceled(
            idToMarketItem[itemId].nftContract,
            itemId,
            idToMarketItem[itemId].tokenId,
            msg.sender
        );
    }

    /// @notice Returns all available market items
    function fetchMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() -
            _itemsSold.current() -
            _itemsCancelled.current();
        uint256 currentIndex = 0;

        MarketItem[] memory items = new MarketItem[](unsoldItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (
                idToMarketItem[i].buyer == address(0) &&
                idToMarketItem[i].isCanceled == false
            ) {
                uint256 currentId = i;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /// @notice Returns only items that a user had bought
    /// @param _user id of market item
    function fetchMyNFTs(address _user)
        public
        view
        returns (MarketItem[] memory)
    {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i].buyer == _user) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i].buyer == _user) {
                uint256 currentId = i;
                MarketItem storage currentItem = idToMarketItem[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /// @notice Returns only items a user had sold
    /// @param _user id of market item
    function fetchItemsCreated(address _user)
        public
        view
        returns (MarketItem[] memory)
    {
        uint256 totalItemCount = _itemIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i].seller == _user && idToMarketItem[i].sold) {
                itemCount += 1;
            }
        }

        MarketItem[] memory items = new MarketItem[](itemCount);
        for (uint256 i = 0; i < totalItemCount; i++) {
            if (idToMarketItem[i].seller == _user && idToMarketItem[i].sold) {
                MarketItem storage currentItem = idToMarketItem[i];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /// @notice get all offers for an item
    /// @param itemId id of market item
    function fetchOffersOfItem(uint256 itemId)
        public
        view
        returns (Offer[] memory)
    {
        uint256 offerCount = idToMarketItem[itemId].offerCount.current();
        uint256 currentIndex = 0;
        Offer[] memory offersOfItem = new Offer[](offerCount);
        for (uint256 i = 0; i < offerCount; i++) {
            Offer storage currentOffer = itemIdToOffer[itemId][i];
            offersOfItem[currentIndex] = currentOffer;
            currentIndex += 1;
        }
        return offersOfItem;
    }

    /// @notice get sell history of an nft
    /// @param tokenId unique id of nft
    function fetchSellHistoryOfToken(uint256 tokenId)
        public
        view
        returns (SellHistory[] memory)
    {
        uint256 historyCount = tokenSellCount[tokenId].current();
        SellHistory[] memory sellHistoriesOfToken = new SellHistory[](
            historyCount
        );
        for (uint256 i = 0; i < historyCount; i++) {
            sellHistoriesOfToken[i] = tokenIdToSellHistory[tokenId][i];
        }
        return sellHistoriesOfToken;
    }

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
        IERC721(idToMarketItem[_itemId].nftContract).transferFrom(
            address(this),
            idToMarketItem[_itemId].seller,
            idToMarketItem[_itemId].tokenId
        );
        idToMarketItem[_itemId].isCanceled = true;
        idToMarketItem[_itemId].seller.transfer(listingPrice);
        _itemsCancelled.increment();
        emit ItemCanceled(
            idToMarketItem[_itemId].nftContract,
            _itemId,
            idToMarketItem[_itemId].tokenId,
            msg.sender
        );
    }

    function lend(
        address nftContract,
        uint256 tokenId,
        uint256 priceLend,
        uint256 lendBlockDuration
    ) public payable {
        require(
            msg.value == listingPrice,
            'Order fee must be equal to listing price'
        );
        require(priceLend > 0, 'The price you set is less than 0');
        require(lendBlockDuration > block.number);
        uint256 itemId = _itemLendIds.current();
        lendItems[itemId] = LendItem(
            nftContract,
            itemId,
            tokenId,
            payable(msg.sender),
            payable(address(0)),
            priceLend,
            false,
            false,
            false,
            lendBlockDuration
        );
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        _itemLendIds.increment();
        emit LendItemCreated(
            nftContract,
            itemId,
            tokenId,
            msg.sender,
            priceLend,
            lendBlockDuration
        );
    }

    function borrow(uint256 itemId) public payable {
        uint256 currentBlock = block.number;
        uint256 tokenId = lendItems[itemId].tokenId;
        require(
            msg.value == lendItems[itemId].priceLend,
            'Price must equal to priceLend'
        );
        require(
            msg.sender != lendItems[itemId].lender,
            'asker must not be owner'
        );
        require(lendItems[itemId].lent == false, 'item has been lent');
        require(
            lendItems[itemId].lendBlockDuration >= currentBlock,
            'Item has been expired'
        );
        require(!lendItems[itemId].isCanceled);
        lendItems[itemId].borrower = payable(msg.sender);
        lendItems[itemId].lent = true;
        uint256 newLendHistoryId = tokenLendCount[tokenId].current();
        _itemsLent.increment();
        LendHistory memory lendHistory = LendHistory(
            newLendHistoryId,
            itemId,
            tokenId,
            lendItems[itemId].lender,
            lendItems[itemId].borrower,
            msg.value,
            currentBlock
        );
        tokenIdToLendHistory[tokenId][newLendHistoryId] = lendHistory;
        tokenLendCount[tokenId].increment();
        lendItems[itemId].lender.transfer(msg.value);
        IERC721(lendItems[itemId].nftContract).transferFrom(
            address(this),
            msg.sender,
            tokenId
        );
        INFT(lendItems[itemId].nftContract).lock(tokenId);
        payable(owner).transfer(listingPrice);
        emit ItemBorrow(
            lendItems[itemId].nftContract,
            itemId,
            tokenId,
            msg.sender
        );
    }

    function retrieve(uint256 itemId) public {
        uint256 tokenId = lendItems[itemId].tokenId;
        require(!lendItems[itemId].paid);
        require(block.number >= lendItems[itemId].lendBlockDuration);
        require(msg.sender == lendItems[itemId].lender);
        INFT(lendItems[itemId].nftContract).unlock(tokenId);
        IERC721(lendItems[itemId].nftContract).transferFrom(
            lendItems[itemId].borrower,
            msg.sender,
            tokenId
        );
        lendItems[itemId].paid = true;
        emit RetrieveItem(
            lendItems[itemId].nftContract,
            itemId,
            tokenId,
            block.number,
            block.timestamp,
            msg.sender
        );
    }

    function cancelLend(uint256 _itemId) public {
        require(
            lendItems[_itemId].lender == msg.sender,
            'caller must be the lender'
        );
        require(!lendItems[_itemId].isCanceled, 'item has been cancelled');
        require(
            lendItems[_itemId].borrower == address(0),
            'item has been sold'
        );
        IERC721(lendItems[_itemId].nftContract).transferFrom(
            address(this),
            lendItems[_itemId].lender,
            lendItems[_itemId].tokenId
        );
        lendItems[_itemId].isCanceled = true;
        lendItems[_itemId].lender.transfer(listingPrice);
        emit LendCanceled(
            lendItems[_itemId].nftContract,
            _itemId,
            lendItems[_itemId].tokenId,
            msg.sender
        );
    }

    function getLend(uint256 _itemId) public view returns (LendItem memory) {
        return lendItems[_itemId];
    }

    function fetchAllLendItem() public view returns (LendItem[] memory) {
        uint256 itemCount = _itemLendIds.current();
        uint256 unLendItemCount = _itemLendIds.current() -
            _itemsLent.current() -
            _isCancelLent.current();
        uint256 currentIndex = 0;

        LendItem[] memory items = new LendItem[](unLendItemCount);
        for (uint256 i = 0; i < itemCount; i++) {
            if (
                lendItems[i].borrower == address(0) &&
                lendItems[i].isCanceled == false
            ) {
                uint256 currentId = i;
                LendItem storage currentItem = lendItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchMyBorrow(address _user)
        public
        view
        returns (LendItem[] memory)
    {
        uint256 totalMyBorrowCount = _itemLendIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalMyBorrowCount; i++) {
            if (lendItems[i].borrower == _user) {
                itemCount += 1;
            }
        }

        LendItem[] memory items = new LendItem[](itemCount);

        for (uint256 i = 0; i < totalMyBorrowCount; i++) {
            if (lendItems[i].borrower == _user) {
                uint256 currentId = i;
                LendItem storage currentItem = lendItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchMyLend(address _user)
        public
        view
        returns (LendItem[] memory)
    {
        uint256 totalMyLendCount = _itemLendIds.current();
        uint256 itemCount = 0;
        uint256 currentIndex = 0;

        for (uint256 i = 0; i < totalMyLendCount; i++) {
            if (lendItems[i].lender == _user) {
                itemCount += 1;
            }
        }

        LendItem[] memory items = new LendItem[](itemCount);

        for (uint256 i = 0; i < totalMyLendCount; i++) {
            if (lendItems[i].lender == _user) {
                uint256 currentId = i;
                LendItem storage currentItem = lendItems[currentId];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    function fetchLendHistory(uint256 tokenId)
        public
        view
        returns (LendHistory[] memory)
    {
        uint256 historyCount = tokenLendCount[tokenId].current();
        LendHistory[] memory lendHistories = new LendHistory[](historyCount);
        for (uint256 i = 0; i < historyCount; i++) {
            lendHistories[i] = tokenIdToLendHistory[tokenId][i];
        }
        return lendHistories;
    }
}
