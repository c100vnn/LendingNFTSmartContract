// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract DargonMarketPlace is ReentrancyGuard {
    using Counters for Counters.Counter;
    // stored current itemid
    Counters.Counter private _itemIds;
    // stored number of item sold
    Counters.Counter private _itemsSold;
    // emit when create a market item
    event MarketItemCreated(
        uint256 indexed itemId,
        address indexed nftContract,
        uint256 indexed tokenId,
        address seller,
        address owner,
        uint256 price,
        bool sold
    );
    // emit when user make offer to an item
    event MakeOfferEvent(
        address _from,
        uint256 _itemId,
        uint256 _amount,
        uint256 _offerId
    );
    // emit when user call refund
    event RefundEvent(
        address _sender,
        uint256 _itemId,
        uint256 _offerId,
        uint256 _amount
    );
    // emit when seller select offer of item
    event SelectOfferEvent(
        address _sender,
        address _receiver,
        uint256 _itemId,
        uint256 _offerId,
        uint256 _amount
    );
    // emit when user buy directly an item
    event DirectlyBuyEvent(
        address _sender,
        address _receiver,
        uint256 _itemId,
        uint256 _amount
    );
    // emit when cancel a market item c
    event CancelMarketItem(address _sender, uint256 _itemId);
    // stored nft infor that up to sale
    struct MarketItem {
        uint256 itemId;
        address nftContract;
        uint256 tokenId;
        address seller;
        address owner;
        uint256 price;
        bool sold;
        bool isCanceled;
        uint256 offerWin;
    }
    // stored offer information of an item
    struct Offer {
        uint256 offerId;
        address asker;
        uint256 amount;
        bool refunable;
    }
    // address of token erc20
    address tokenBase;
    // id of item to market item
    mapping(uint256 => MarketItem) private idToMarketItem;
    // itemToOffer[itemId][offerId] to get offer
    mapping(uint256 => mapping(uint256 => Offer)) private itemToOffer;
    // offerCount[itemId] to get numbers of offer
    mapping(uint256 => uint256) offerCount;

    constructor(address _tokenBase) {
        tokenBase = _tokenBase;
        //owner = payable(msg.sender);
    }

    /**
     * create a market item.
     * @param nftContract: address of nft contract
     * @param tokenId: id of token in nft contract
     * @param price: price in tokenBase
     */
    function createMarketItem(
        address nftContract,
        uint256 tokenId,
        uint256 price
    ) public nonReentrant {
        require(
            IERC721(nftContract).ownerOf(tokenId) == msg.sender,
            "sender is not owner"
        );
        require(price > 0, "the price must be bigger than zero");
        uint256 itemId = _itemIds.current();

        idToMarketItem[itemId] = MarketItem(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            false,
            false,
            0
        );
        offerCount[itemId]=1;
        // tokenId must be approved for this contract
        IERC721(nftContract).transferFrom(msg.sender, address(this), tokenId);
        _itemIds.increment();
        emit MarketItemCreated(
            itemId,
            nftContract,
            tokenId,
            msg.sender,
            address(0),
            price,
            false
        );
    }
    // function changePriceOfMarketItem(uint256 itemId, uint256 price) public nonReentrant {
    //     require(msg.sender != idToMarketItem[itemId].seller, "owner must not sender");
    //     require(idToMarketItem[itemId].sold == false, "Item has been sold");
    //     require(
    //         idToMarketItem[itemId].isCanceled == false,
    //         "Item has been canceled"
    //     );
    //     idToMarketItem[itemId].price = price;
    // }
    /**
     * buy item directly from a market item
     * @param itemId: id of market item
     */
    function buyItemDirectly(uint256 itemId) public nonReentrant {
        require(msg.sender != idToMarketItem[itemId].seller, "owner must not sender");
        require(idToMarketItem[itemId].sold == false, "Item has been sold");
        require(
            idToMarketItem[itemId].isCanceled == false,
            "Item has been canceled"
        );
        uint256 price = idToMarketItem[itemId].price;
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        address seller = idToMarketItem[itemId].seller;
        address nftContract = idToMarketItem[itemId].nftContract;
        //ERC20 token must approve
        IERC20(tokenBase).transferFrom(msg.sender, seller, price);
        IERC721(nftContract).transferFrom(address(this), msg.sender, tokenId);
        //IERC721(nftContract).(seller, msg.sender, tokenId);
        idToMarketItem[itemId].owner = msg.sender;
        idToMarketItem[itemId].sold = true;
        _itemsSold.increment();
        emit DirectlyBuyEvent(msg.sender, seller, itemId, price);
    }

    /**
     * make an offer for market item
     * @param itemId: id of market item
     * @param offerPrice: offer price want to set
     */
    function createMarketOffer(uint256 itemId, uint256 offerPrice)
        public
        nonReentrant
    {
        require(msg.sender != idToMarketItem[itemId].seller, "owner must not sender");
        require(idToMarketItem[itemId].sold == false, "Item has been sold");
        require(
            idToMarketItem[itemId].isCanceled == false,
            "Item has been canceled"
        );
        uint256 price = idToMarketItem[itemId].price;
        require(offerPrice < price, "Offer price must less than item price");
        IERC20(tokenBase).transferFrom(msg.sender, address(this), offerPrice);
        uint256 offerId = offerCount[itemId];
        Offer memory newOffer;
        newOffer.offerId = offerId;
        newOffer.asker = msg.sender;
        newOffer.amount = offerPrice;
        newOffer.refunable = true;
        itemToOffer[itemId][offerId] = newOffer;
        offerCount[itemId] = offerId + 1;
        emit MakeOfferEvent(msg.sender, itemId, offerPrice, offerId);
    }

    /**
     * seller select offer
     * @param itemId: id of market item
     * @param offerId: id of offer
     */
    function selectOffer(uint256 itemId, uint256 offerId) public {
        uint256 tokenId = idToMarketItem[itemId].tokenId;
        address nftContract = idToMarketItem[itemId].nftContract;
        require(
            idToMarketItem[itemId].seller == msg.sender,
            "sender is not owner"
        );
        require(
            itemToOffer[itemId][offerId].refunable == true,
            "Offer was refuned"
        );
        require(idToMarketItem[itemId].sold == false, "item was already sold");
        require(
            idToMarketItem[itemId].isCanceled == false,
            "Item was canceled"
        );
        IERC721(nftContract).transferFrom(address(this), itemToOffer[itemId][offerId].asker, tokenId);
        IERC20(tokenBase).transfer(msg.sender, itemToOffer[itemId][offerId].amount);
        //IERC721(nftContract).(seller, msg.sender, tokenId);
        itemToOffer[itemId][offerId].refunable = false;
        idToMarketItem[itemId].owner = itemToOffer[itemId][offerId].asker;
        idToMarketItem[itemId].sold = true;
        idToMarketItem[itemId].offerWin = offerId;
        _itemsSold.increment();
        
        emit SelectOfferEvent(
            itemToOffer[itemId][offerId].asker,
            msg.sender,
            itemId,
            offerId,
            idToMarketItem[itemId].price
        );
    }

    /**
     * RefundOffer
     * @param itemId: id of market item
     * @param offerId: id of offer
     */
    function refundOffer(uint256 itemId, uint256 offerId) public {
        require(
            itemToOffer[itemId][offerId].refunable == true,
            "Offer has arlready refunded"
        );
        require(
            idToMarketItem[itemId].offerWin != offerId,
            "Winner can't refund"
        );
        require(
            itemToOffer[itemId][offerId].asker == msg.sender,
            "Sender isn't offer owner"
        );

        IERC20(tokenBase).transfer(
            msg.sender,
            itemToOffer[itemId][offerId].amount
        );
        itemToOffer[itemId][offerId].refunable = false;
        emit RefundEvent(
            msg.sender,
            itemId,
            offerId,
            itemToOffer[itemId][offerId].amount
        );
    }

    /**
     * Cancel an market item
     * @param itemId: id of market item
     */
    function cancelMarketItem(uint256 itemId) public {
        require(
            idToMarketItem[itemId].seller == msg.sender,
            "sender is not item owner"
        );
        require(idToMarketItem[itemId].sold == false, "Item has been sold");
        require(
            idToMarketItem[itemId].isCanceled == false,
            "Item has been canceled"
        );

        // tokenId must be approved for this contract
        IERC721(idToMarketItem[itemId].nftContract).transferFrom(
            address(this),
            msg.sender,
            idToMarketItem[itemId].tokenId
        );
        idToMarketItem[itemId].isCanceled = true;
        emit CancelMarketItem(msg.sender, itemId);
    }

    /**
     * get all market item stored in contract
     */
    function getMarketItems() public view returns (MarketItem[] memory) {
        uint256 itemCount = _itemIds.current();
        uint256 unsoldItemCount = _itemIds.current() - _itemsSold.current();
        uint256 currentIndex = 0;
        MarketItem[] memory items = new MarketItem[](unsoldItemCount);

        for (uint256 i = 0; i < itemCount; i++) {
            if (idToMarketItem[i].owner == address(0)) {
                //uint256 currentId = i + 1;
                MarketItem storage currentItem = idToMarketItem[i];
                items[currentIndex] = currentItem;
                currentIndex += 1;
            }
        }
        return items;
    }

    /**
     * get a market item stored in contract
     * @param itemId: id of market item
     */
    function getMarketItem(uint256 itemId)
        public
        view
        returns (MarketItem memory)
    {
        return idToMarketItem[itemId];
    }
    
    function getOfferOfItem(uint256 itemId)
        public
        view
        returns (Offer[] memory)
    {
        //uint256 offerCount =  offerCount[itemId];
        uint256 currentIndex = 0;
        Offer[] memory offers = new Offer[](offerCount[itemId]);
        for (uint256 i = 0; i < offerCount[itemId]; i++) {
            offers[currentIndex] = itemToOffer[itemId][i];
            currentIndex += 1;
        }
        return offers;
    }

    /**
     * get erc20 token base balance of this contract
     */
    function getContractERC20Balance() public view returns (uint256) {
        return IERC20(tokenBase).balanceOf(address(this));
    }
}
