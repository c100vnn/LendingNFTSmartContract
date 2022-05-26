// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./IBaseDoNFT.sol";

interface IComplexDoNFT is IBaseDoNFT {
    function initialize(
        string memory name_,
        string memory symbol_,
        address nftAddress_,
        address market_,
        address owner_,
        address admin_
    ) external;
}
