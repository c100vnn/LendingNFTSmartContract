// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/cryptography/ECDSA.sol';
import '@openzeppelin/contracts/access/AccessControl.sol';

contract LendNFT is AccessControl, ERC721, ReentrancyGuard {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    Counters.Counter private _itemIds;
    address tokenBaseAddress;
    bytes32 public constant MINTER_ROLE = keccak256('MINTER_ROLE');
    uint256[] priceLevels = [1000000000000000000000, 3000000000000000000000];
    event SeedBoxOpened(
        uint256 tokenId,
        address owner,
        uint256 timestamp,
        uint256 level
    );
    event SeedBoxOpenedWithSignature(
        uint256 tokenId,
        address owner,
        uint256 timestamp
    );
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
    mapping(uint256 => MarketItem) public idToMarketItem;
    mapping(address => bool) public approvalWhitelists;

    constructor(address _tokenBaseAddress) ERC721('Farm Finance NFT', 'FFN') {
        tokenBaseAddress = _tokenBaseAddress;
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    /**
     * @dev See {IERC721-isApprovedForAll}.
     */
    function isApprovedForAll(address owner, address operator)
        public
        view
        override
        returns (bool)
    {
        if (approvalWhitelists[operator] == true) {
            return true;
        }

        return super.isApprovedForAll(owner, operator);
    }

    /**
     * @dev Allow operation to reduce gas fee.
     */
    function addApprovalWhitelist(address proxy)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            approvalWhitelists[proxy] == false,
            'GameNFT: invalid proxy address'
        );

        approvalWhitelists[proxy] = true;
    }

    /**
     * @dev Remove operation from approval list.
     */
    function removeApprovalWhitelist(address proxy)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        approvalWhitelists[proxy] = false;
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
    function setGachaPrice(uint8 level, uint256 price)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(level < priceLevels.length, 'level invalid');
        priceLevels[level] = price;
    }

    /**
     * Open seed box is function for create a new token
     * @param level: we have 2 levels: 0,1
     */
    function openSeedBox(uint8 level) public nonReentrant {
        require(level < priceLevels.length);
        require(level >= 0);
        //need to approve first
        IERC20(tokenBaseAddress).transferFrom(
            msg.sender,
            address(this),
            priceLevels[level]
        );
        uint256 tokenId = _tokenIds.current();
        _mint(msg.sender, tokenId);
        _tokenIds.increment();
        emit SeedBoxOpened(tokenId, msg.sender, block.timestamp, level);
    }

    function openSeedBoxWithSignature(
        address requestAccount,
        bytes memory _hash,
        bytes memory signature
    ) public onlyRole(MINTER_ROLE) {
        require(requestAccount != address(0));

        bytes32 ethSignedMessageHash = ECDSA.toEthSignedMessageHash(_hash);

        if (ECDSA.recover(ethSignedMessageHash, signature) != requestAccount) {
            revert('Signature does not match message sender');
        }
        uint256 tokenId = _tokenIds.current();
        _mint(requestAccount, tokenId);
        _tokenIds.increment();
        emit SeedBoxOpenedWithSignature(
            tokenId,
            requestAccount,
            block.timestamp
        );
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
        _transfer(msg.sender, address(this), _tokenId);
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
        require(!idToMarketItem[_itemId].sold, 'item has been sold');
        require(!idToMarketItem[_itemId].isCanceled, 'Item has been cancelled');
        idToMarketItem[_itemId].buyer = msg.sender;
        idToMarketItem[_itemId].sold = true;
        IERC20(tokenBaseAddress).transferFrom(
            msg.sender,
            idToMarketItem[_itemId].seller,
            idToMarketItem[_itemId].price
        );
        _transfer(address(this), msg.sender, idToMarketItem[_itemId].tokenId);
        // transferFrom(
        //     address(this),
        //     msg.sender,
        //     idToMarketItem[_itemId].tokenId
        // );
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
        _transfer(address(this), msg.sender, idToMarketItem[_itemId].tokenId);
        // transferFrom(
        //     address(this),
        //     msg.sender,
        //     idToMarketItem[_itemId].tokenId
        // );
        idToMarketItem[_itemId].isCanceled = true;
        emit MarketItemCanceled(
            _itemId,
            idToMarketItem[_itemId].tokenId,
            idToMarketItem[_itemId].price,
            idToMarketItem[_itemId].seller,
            block.timestamp
        );
    }

    function withdrawToken() public onlyRole(DEFAULT_ADMIN_ROLE) {
        uint256 amount = IERC20(tokenBaseAddress).balanceOf(address(this));
        require(
            IERC20(tokenBaseAddress).balanceOf(address(this)) > 0,
            'contract out of token'
        );
        IERC20(tokenBaseAddress).transfer(msg.sender, amount);
    }
}
