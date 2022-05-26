// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import './OwnableContract.sol';
import './ERC/wrap/WrapERC721DualRole.sol';
import '@openzeppelin/contracts/token/ERC721/IERC721.sol';

contract DoNFTFactory is OwnableContract {
    event DeployWrapERC721DualRole(
        address wrapNFT,
        string name,
        string symbol,
        address originalAddress
    );

    mapping(address => mapping(string => address)) private doNftMapping;

    constructor() {
        initOwnableContract(msg.sender, msg.sender);
    }

    function deployWrapERC721DualRole(
        string memory name,
        string memory symbol,
        address originalAddress
    ) public returns (WrapERC721DualRole wrapNFT) {
        require(
            IERC165(originalAddress).supportsInterface(
                type(IERC721).interfaceId
            ),
            'not ERC721'
        );
        wrapNFT = new WrapERC721DualRole(name, symbol, originalAddress);
        emit DeployWrapERC721DualRole(
            address(wrapNFT),
            name,
            symbol,
            originalAddress
        );
    }
}
