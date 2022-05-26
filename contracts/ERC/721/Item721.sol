// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/extensions/ERC721Pausable.sol";
import "./IERC20.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

contract Item721 is Ownable, ERC721Pausable, AccessControl {
    using Counters for Counters.Counter;

    constructor(address _tokenBaseAddress) ERC721("Item721 NFT", "CNFT") {
        _setupRole(DEFAULT_ADMIN_ROLE, _msgSender());
        tokenBaseAddress = _tokenBaseAddress;
        addBox(100 * 10**18);
    }

    Counters.Counter private _tokenIdCount;
    Counters.Counter private _boxIdCount;
    Counters.Counter private _imgIdCount;
    address public tokenBaseAddress;
    string public baseTokenURI;

    struct Box {
        uint256 price;
    }

    struct Item {
        uint256 imgId;
    }

    mapping(uint256 => Box) _idToBox;
    mapping(uint256 => Item) _idToItem;

    event BoxAdded(uint256 _gachaId, uint256 _price);

    event BoxUpdated(uint256 _price);

    event BoxOpened(uint256 _tokenId, address _owner);

    function pause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(DEFAULT_ADMIN_ROLE) {
        _unpause();
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return baseTokenURI;
    }

    function setBaseURI(string memory baseURI)
        public
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        baseTokenURI = baseURI;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(AccessControl, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function addBox(uint256 _price) public onlyRole(DEFAULT_ADMIN_ROLE) {
        _boxIdCount.increment();
        uint256 _boxId = _boxIdCount.current();
        Box storage box = _idToBox[_boxId];
        box.price = _price;
        emit BoxAdded(_boxId, _price);
    }

    function updateBox(uint256 _boxId, uint256 _price)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        Box storage box = _idToBox[_boxId];
        box.price = _price;
        emit BoxUpdated(_price);
    }

    function _createItem(address _owner) internal {
        _tokenIdCount.increment();
        _imgIdCount.increment();
        uint256 id = _tokenIdCount.current();
        uint256 imgId = _imgIdCount.current();
        _mint(_owner, id);
        Item memory item = Item(imgId);
        _idToItem[id] = item;
        emit BoxOpened(id, _owner);
    }

    function buyBox(uint8 _boxId) external {
        IERC20(tokenBaseAddress).transferFrom(
            msg.sender,
            address(this),
            _idToBox[_boxId].price
        );
        _createItem(msg.sender);
    }

    function buyMultiGachaBox(uint8 _quantity, uint8 _boxId) external {
        IERC20(tokenBaseAddress).transferFrom(
            msg.sender,
            address(this),
            _idToBox[_boxId].price * _quantity
        );
        // mint one by one
        for (uint256 i = 0; i < _quantity; i++) {
            _createItem(msg.sender);
        }
    }

    function burn(uint256 _tokenId) external {
        require(_exists(_tokenId), "Item: tokenId don't exist");
        require(
            ownerOf(_tokenId) == msg.sender,
            "Item: You are not the owner"
        );
        _burn(_tokenId);
        delete _idToBox[_tokenId];
    }

    function withdrawToken(
        address _tokenAddress,
        address _receiver,
        uint256 _amount
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            _amount <= IERC20(tokenBaseAddress).balanceOf(address(this)),
            "Item: not enough balance"
        );
        IERC20(_tokenAddress).transfer(_receiver, _amount);
    }

}
