// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721URIStorage.sol';
import '@openzeppelin/contracts/utils/Counters.sol';
import '@openzeppelin/contracts/token/ERC721/extensions/ERC721Enumerable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import './interface/INFT.sol';

contract NFT is ERC721URIStorage, ERC721Enumerable, Ownable {
    using Counters for Counters.Counter;
    Counters.Counter private _tokenIds;
    address marketAddress;

    uint8 constant BEAST = 1; // Beast
    uint8 constant PLANT = 2; // Plant
    uint8 constant BUG = 3; // Dusk
    uint8 constant MECH = 4; // Mech

    struct State {
        uint8 class;
        uint256 level;
        uint256 heath;
        uint256 speed;
        uint256 skill;
        uint256 morale;
    }
    uint256 levelUpFee = 0.001 ether;

    mapping(uint256 => State) public tokenDetails;
    mapping(uint256 => bool) public isLockItem;

    event CreateToken(
        uint8 _class,
        uint256 level,
        uint256 heath,
        uint256 speed,
        uint256 skill,
        uint256 morale,
        address owner,
        uint256 tokenId
    );

    event UpgradeLevel(
        address owner,
        uint256 tokenId,
        uint8 _class,
        uint256 level,
        uint256 heath,
        uint256 speed,
        uint256 skill,
        uint256 morale
    );

    constructor(address marketPlaceAddress) ERC721('Vnext Token', 'VNT') {
        marketAddress = marketPlaceAddress;
    }

    function createToken(
        string calldata tokenURI_,
        uint8 class_,
        uint256 level_,
        uint256 heath_,
        uint256 speed_,
        uint256 skill_,
        uint256 morale_
    ) public onlyOwner returns (uint256) {
        uint256 newItemId = _tokenIds.current();
        _mint(msg.sender, newItemId);
        _setTokenURI(newItemId, tokenURI_);
        setApprovalForAll(marketAddress, true);
        tokenDetails[newItemId] = State(
            class_,
            level_,
            heath_,
            speed_,
            skill_,
            morale_
        );
        _tokenIds.increment();
        emit CreateToken(
            class_,
            level_,
            heath_,
            speed_,
            skill_,
            morale_,
            msg.sender,
            newItemId
        );
        return newItemId;
    }

    function _burn(uint256 tokenId)
        internal
        virtual
        override(ERC721URIStorage, ERC721)
    {
        super._burn(tokenId);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override(ERC721Enumerable, ERC721) {
        super._beforeTokenTransfer(from, to, tokenId);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC721Enumerable, ERC721)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }

    function tokenURI(uint256 tokenId)
        public
        view
        virtual
        override(ERC721URIStorage, ERC721)
        returns (string memory)
    {
        return super.tokenURI(tokenId);
    }

    function setLevelUpFee(uint256 _fee) external onlyOwner {
        levelUpFee = _fee;
    }

    function upgradeLevel(uint256 _NFTId) public payable {
        require(
            msg.sender == ownerOf(_NFTId),
            'Caller is not the owner of the token'
        );
        require(msg.value == levelUpFee, 'Fee not enough');
        tokenDetails[_NFTId].level++;
        tokenDetails[_NFTId].heath++;
        tokenDetails[_NFTId].speed++;
        tokenDetails[_NFTId].skill++;
        tokenDetails[_NFTId].morale++;
        emit UpgradeLevel(
            ownerOf(_NFTId),
            _NFTId,
            tokenDetails[_NFTId].class,
            tokenDetails[_NFTId].level,
            tokenDetails[_NFTId].heath,
            tokenDetails[_NFTId].speed,
            tokenDetails[_NFTId].skill,
            tokenDetails[_NFTId].morale
        );
    }

    function _transfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        require(!isLockItem[tokenId], "Token is locked");
        super._transfer(from, to, tokenId);
    }

    function lock(uint256 tokenId) public {
        require(msg.sender == marketAddress);
        isLockItem[tokenId] = true;
    }

    function unlock(uint256 tokenId) public {
        require(msg.sender == marketAddress);
        isLockItem[tokenId] = false;
    }
}
