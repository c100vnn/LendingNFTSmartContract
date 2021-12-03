// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

interface INFT is IERC721 {
    // event Lock(uint256 indexed tokenId);
    // event UnLock(uint256 indexed tokenId);

    function lock(uint256 tokenId) external;
    function unlock(uint256 tokenId) external;
}