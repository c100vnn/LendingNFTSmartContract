// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import './BaseDoNFT.sol';
import './IBaseDoNFT.sol';

abstract contract BaseNFT is BaseDoNFT {
    function mintDoNft(
        address to,
        uint256 oid_,
        uint64 start,
        uint64 end
    ) internal override returns (uint256) {
        newDoNft(oid_, start, end);
        _safeMint(to, curDoid);
        return curDoid;
    }

    function checkIn(
        address to,
        uint256 tokenId,
        uint256 durationId
    ) public virtual override {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            'not owner nor approved'
        );
        DoNftInfo storage info = doNftMapping[tokenId];
        Duration storage duration = durationMapping[durationId];
        require(duration.end >= block.timestamp, 'invalid end');
        require(duration.start <= block.timestamp, 'invalid start');
        require(info.durationList.contains(durationId), 'not contains');

        emit CheckIn(
            msg.sender,
            to,
            tokenId,
            durationId,
            info.oid,
            duration.end
        );
    }
}
