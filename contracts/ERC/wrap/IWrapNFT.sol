// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

interface IWrapNFT is IERC721Receiver {
    event Redeem(address msgSender, address nftAddress, uint256 tokenId);

    function originalAddress() external view returns (address);

    function redeem(uint256 tokenId) external;
}
