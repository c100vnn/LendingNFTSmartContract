// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '../WrapDoNFT.sol';
import '../ERC/IERC4907.sol';
import '../ERC/wrap/IWrapNFT.sol';

contract vNFT is WrapDoNFT {
    function mintVNft(uint256 oid)
        public
        virtual
        override
        nonReentrant
        returns (uint256 tid)
    {
        require(oid2vid[oid] == 0, 'already warped');
        address lastOwner;

        if (
            IERC165(oNftAddress).supportsInterface(type(IWrapNFT).interfaceId)
        ) {
            address gameNFTAddress = IWrapNFT(oNftAddress).originalAddress();
            lastOwner = ERC721(gameNFTAddress).ownerOf(oid);
            if (lastOwner != oNftAddress) {
                require(
                    onlyApprovedOrOwner(msg.sender, gameNFTAddress, oid),
                    'only approved or owner'
                );
                ERC721(gameNFTAddress).safeTransferFrom(
                    lastOwner,
                    address(this),
                    oid
                );
                ERC721(gameNFTAddress).approve(oNftAddress, oid);
                oid = IWrapNFT(oNftAddress).stake(oid);
            } else {
                require(
                    onlyApprovedOrOwner(msg.sender, oNftAddress, oid),
                    'only approved or owner'
                );
                lastOwner = ERC721(oNftAddress).ownerOf(oid);
                ERC721(oNftAddress).safeTransferFrom(
                    lastOwner,
                    address(this),
                    oid
                );
            }
        } else {
            require(
                onlyApprovedOrOwner(msg.sender, oNftAddress, oid),
                'only approved or owner'
            );
            lastOwner = ERC721(oNftAddress).ownerOf(oid);
            ERC721(oNftAddress).safeTransferFrom(lastOwner, address(this), oid);
        }
        tid = mintDoNft(
            lastOwner,
            oid,
            uint64(block.timestamp),
            type(uint64).max
        );
        oid2vid[oid] = tid;
    }

    function redeem(uint256 tokenId, uint256[] calldata durationIds)
        public
        virtual
        override
    {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            'ERC721: transfer caller is not owner nor approved'
        );
        require(couldRedeem(tokenId, durationIds), 'cannot redeem');
        DoNftInfo storage info = doNftMapping[tokenId];

        if (
            IERC165(oNftAddress).supportsInterface(type(IWrapNFT).interfaceId)
        ) {
            IWrapNFT(oNftAddress).redeem(info.oid);
            address gameNFTAddress = IWrapNFT(oNftAddress).originalAddress();
            ERC721(gameNFTAddress).safeTransferFrom(
                address(this),
                ownerOf(tokenId),
                info.oid
            );
        } else {
            ERC721(oNftAddress).safeTransferFrom(
                address(this),
                ownerOf(tokenId),
                info.oid
            );
        }

        _burnVNft(tokenId);
        emit Redeem(info.oid, tokenId);
    }
}
