// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;


import '@openzeppelin/contracts/token/ERC721/ERC721.sol';
import '@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/token/ERC721/ERC721Upgradeable.sol';
import './OwnableContract.sol';
import '@openzeppelin/contracts/utils/structs/EnumerableSet.sol';

abstract contract BaseDoNFT is
    OwnableContract,
    ERC721Upgradeable,
    ReentrancyGuardUpgradeable
{
    using EnumerableSet for EnumerableSet.UintSet;
    using Strings for uint256;

    address internal oNftAddress;
    address public market;
    uint256 public curDoid;
    uint256 public curDurationId;
    uint64 public maxDuration;

    struct DoNftInfo {
        uint256 oid;
        uint64 nonce;
        EnumerableSet.UintSet durationList;
    }
    struct Duration {
        uint64 start;
        uint64 end;
    }

    event MetadataUpdate(uint256 tokenId);
    event DurationUpdate(
        uint256 durationId,
        uint256 tokenId,
        uint64 start,
        uint64 end
    );
    event DurationBurn(uint256[] durationIdList);
    event CheckIn(
        address opreator,
        address to,
        uint256 tokenId,
        uint256 durationId,
        uint256 oid,
        uint64 expires
    );
    event Redeem(uint256 oid, uint256 tokenId);

    mapping(uint256 => DoNftInfo) internal doNftMapping;
    mapping(uint256 => Duration) internal durationMapping;
    mapping(uint256 => uint256) internal oid2vid;
   
    bool private isOnlyNow;

    function _BaseDoNFT_init(
        string memory name_,
        string memory symbol_,
        address address_,
        address market_,
        address owner_,
        address admin_
    ) internal onlyInitializing {
        __ERC721_init(name_, symbol_);
        __ReentrancyGuard_init();
        initOwnableContract(owner_, admin_);
        oNftAddress = address_;
        market = market_;
        isOnlyNow = true;
        maxDuration = 180 days;
    }

    modifier onlyNow(uint64 start) {
        if (isOnlyNow) {
            require(start <= block.timestamp, 'must from now');
        }
        _;
    }

    function onlyApprovedOrOwner(
        address spender,
        address nftAddress,
        uint256 tokenId
    ) internal view returns (bool) {
        if (msg.sender == market) return true;
        address _owner = ERC721(nftAddress).ownerOf(tokenId);
        return (spender == _owner ||
            ERC721(nftAddress).getApproved(tokenId) == spender ||
            ERC721(nftAddress).isApprovedForAll(_owner, spender));
    }

    function setIsOnlyNow(bool v) public onlyAdmin {
        isOnlyNow = v;
    }

    function contains(uint256 tokenId, uint256 durationId)
        public
        view
        returns (bool)
    {
        return doNftMapping[tokenId].durationList.contains(durationId);
    }

    function getDurationIdList(uint256 tokenId)
        external

        override
        view
        returns (uint256[] memory)
    {
        DoNftInfo storage info = doNftMapping[tokenId];
        return info.durationList.values();
    }

    function getDuration(uint256 durationId)
        public

        override

        view
        returns (uint64, uint64)
    {
        Duration storage duration = durationMapping[durationId];
        return (duration.start, duration.end);
    }

    function getDurationByIndex(uint256 tokenId, uint256 index)
        public

        override

        view
        returns (
            uint256 durationId,
            uint64 start,
            uint64 end
        )
    {
        DoNftInfo storage info = doNftMapping[tokenId];

        require(index < info.durationList.length(), "out of range");

        durationId = info.durationList.at(index);
        (start, end) = getDuration(durationId);
        return (durationId, start, end);
    }


    function isValidNow(uint256 tokenId) public override view returns (bool isValid) {

        DoNftInfo storage info = doNftMapping[tokenId];
        uint256 length = info.durationList.length();
        uint256 durationId;
        for (uint256 index = 0; index < length; index++) {
            durationId = info.durationList.at(index);
            if (
                durationMapping[durationId].start <= block.timestamp &&
                block.timestamp <= durationMapping[durationId].end
            ) {
                return true;
            }
        }
        return false;
    }

    function getDurationListLength(uint256 tokenId)
        external

        override
        view
        returns (uint256)
    {
        return doNftMapping[tokenId].durationList.length();
    }

    function getDoNftInfo(uint256 tokenId)
        public

        override
        view
        returns (
            uint256 oid,
            uint256[] memory durationIds,
            uint64[] memory starts,
            uint64[] memory ends,
            uint64 nonce
        )
    {
        DoNftInfo storage info = doNftMapping[tokenId];
        oid = info.oid;
        nonce = info.nonce;
        uint256 length = info.durationList.length();
        uint256 durationId;
        starts = new uint64[](length);
        ends = new uint64[](length);
        durationIds = info.durationList.values();
        for (uint256 index = 0; index < length; index++) {
            durationId = info.durationList.at(index);
            starts[index] = durationMapping[durationId].start;
            ends[index] = durationMapping[durationId].end;
        }
    }


    function getNonce(uint256 tokenId) external override view returns (uint64) {
        return doNftMapping[tokenId].nonce;
    }

    function mint(
        uint256 tokenId,
        uint256 durationId,
        uint64 start,
        uint64 end,
        address to,
        address user

    ) public override onlyNow(start) nonReentrant returns (uint256 tid) {

        if (start < block.timestamp) {
            start = uint64(block.timestamp);
        }
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),

            'not owner nor approved'
        );
        require(
            end > start && end <= block.timestamp + maxDuration,
            'invalid start or end'
        );
        DoNftInfo storage info = doNftMapping[tokenId];
        require(contains(tokenId, durationId), 'not contains durationId');
        Duration storage duration = durationMapping[durationId];
        require(
            start >= duration.start && end <= duration.end,
            'invalid duration'

        );
        uint256 tDurationId;
        if (start == duration.start && end == duration.end) {
            tid = mintDoNft(to, info.oid, start, end);
            tDurationId = curDurationId;
            _burnDuration(tokenId, durationId);
            if (info.durationList.length() == 0) {
                _burn(tokenId);
            }
        } else {
            if (start == duration.start && end != duration.end) {
                duration.start = end + 1;
            } else if (start != duration.start && end == duration.end) {
                duration.end = start - 1;
            } else {
                if (start > block.timestamp) {
                    newDuration(tokenId, duration.start, start - 1);
                }
                duration.start = end + 1;
            }

            tid = mintDoNft(to, info.oid, start, end);
            tDurationId = curDurationId;
        }

        if (start == block.timestamp) {
            checkIn(user, tid, tDurationId);
        }
        emit MetadataUpdate(tokenId);
    }


    function setMaxDuration(uint64 v) public override onlyAdmin {
        maxDuration = v;
    }

    function getMaxDuration() public override view returns (uint64) {

        return maxDuration;
    }

    function newDoNft(
        uint256 oid_,
        uint64 start,
        uint64 end
    ) internal returns (uint256) {
        curDoid++;
        DoNftInfo storage info = doNftMapping[curDoid];
        info.oid = oid_;
        info.nonce = 0;
        newDuration(curDoid, start, end);
        return curDoid;
    }

    function newDuration(
        uint256 tokenId,
        uint64 start,
        uint64 end
    ) private {
        curDurationId++;
        durationMapping[curDurationId] = Duration(start, end);
        doNftMapping[tokenId].durationList.add(curDurationId);
        emit DurationUpdate(curDurationId, tokenId, start, end);
    }

    function mintDoNft(
        address to,
        uint256 oid_,
        uint64 start,
        uint64 end
    ) internal returns (uint256) {
        newDoNft(oid_, start, end);
        _safeMint(to, curDoid);
        return curDoid;
    }

    function concat(
        uint256 tokenId,
        uint256 durationId,
        uint256 targetTokenId,
        uint256 targetDurationId
    ) public {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),

            'ERC721: transfer caller is not owner nor approved'
        );
        require(contains(tokenId, durationId), 'not contains');
        require(ownerOf(tokenId) == ownerOf(targetTokenId), 'diff owner');
        require(
            doNftMapping[tokenId].oid == doNftMapping[targetTokenId].oid,
            'diff oid'
        );
        require(contains(targetTokenId, targetDurationId), 'not contains');

        Duration storage duration = durationMapping[durationId];
        Duration storage targetDuration = durationMapping[targetDurationId];

        if (duration.end < targetDuration.start) {
            require(duration.end + 1 == targetDuration.start);
            targetDuration.start = duration.start;
            _burnDuration(tokenId, durationId);
        } else if (targetDuration.end < duration.start) {
            require(targetDuration.end + 1 == duration.start);
            targetDuration.end = duration.end;
            _burnDuration(tokenId, durationId);
        }

        if (doNftMapping[tokenId].durationList.length() == 0) {
            _burn(tokenId);
        }
    }

    function _burnDuration(uint256 tokenId, uint256 durationId) private {
        delete durationMapping[durationId];
        doNftMapping[tokenId].durationList.remove(durationId);
        uint256[] memory arr = new uint256[](1);
        arr[0] = durationId;
        emit DurationBurn(arr);
    }

    function _burnVNft(uint256 wid) internal {
        DoNftInfo storage info = doNftMapping[wid];
        uint256 length = info.durationList.length();
        for (uint256 index = 0; index < length; index++) {
            delete durationMapping[info.durationList.at(index)];
        }
        emit DurationBurn(info.durationList.values());
        delete info.durationList;
        delete oid2vid[info.oid];
        _burn(wid);
    }

    function _burn(uint256 tokenId) internal virtual override {
        super._burn(tokenId);
        delete doNftMapping[tokenId];
    }

    function checkIn(
        address to,
        uint256 tokenId,
        uint256 durationId

    ) public override virtual {
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

    function gc(uint256 tokenId, uint256[] calldata durationIds) public {
        DoNftInfo storage info = doNftMapping[tokenId];
        uint256 durationId;
        Duration storage duration;
        for (uint256 index = 0; index < durationIds.length; index++) {
            durationId = durationIds[index];
            if (contains(tokenId, durationId)) {
                duration = durationMapping[durationId];
                if (duration.end <= block.timestamp) {
                    _burnDuration(tokenId, durationId);
                }
            }
        }

        if (info.durationList.length() == 0) {

            require(!isVNft(tokenId), 'can not burn vNFT');

            _burn(tokenId);
        }
    }

    function getFingerprint(uint256 tokenId)
        public
        view
        returns (bytes32 print)
    {
        (
            uint256 oid,
            uint256[] memory durationIds,
            uint64[] memory starts,
            uint64[] memory ends,
            uint64 nonce
        ) = getDoNftInfo(tokenId);
        print = keccak256(
            abi.encodePacked(oid, durationIds, starts, ends, nonce)
        );
    }


    function isVNft(uint256 tokenId) public override view returns (bool) {

        if (tokenId == 0) return false;

        return oid2vid[doNftMapping[tokenId].oid] == tokenId;
    }

    function getOriginalNftAddress() external override view returns (address) {
        return oNftAddress;
    }

    function getOriginalNftId(uint256 tokenId) external override view returns (uint256) {

        DoNftInfo storage info = doNftMapping[tokenId];
        return info.oid;
    }


    function getVNftId(uint256 originalNftId) public override view returns (uint256) {

        return oid2vid[originalNftId];
    }

    // function onERC721Received(
    //     address operator,
    //     address from,
    //     uint256 tokenId,
    //     bytes calldata data

    // ) external pure virtual override returns (bytes4) {
    //     bytes4 received = 0x150b7a02;
    //     return received;
    // }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 tokenId
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, tokenId);
        doNftMapping[tokenId].nonce++;
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override
        returns (bool)
    {
        return
            interfaceId == type(IBaseDoNFT).interfaceId ||
            super.supportsInterface(interfaceId);
    }

    function exists(uint256 tokenId) public override view virtual returns (bool) {
        return _exists(tokenId);
    }

    function _isApprovedOrOwner(address spender, uint256 tokenId)
        internal
        view
        virtual
        override
        returns (bool)
    {
        if (spender == market) return true;
        return super._isApprovedOrOwner(spender, tokenId);
    }

    function setMarket(address _market) public onlyOwner {
        uint256 id;
        assembly {
            id := chainid()
        }
        require(id == 4 || id == 97, 'only for rinkeby or bsct');
        market = _market;
    }

    function multicall(bytes[] calldata data)
        external
        returns (bytes[] memory results)
    {
        results = new bytes[](data.length);
        for (uint256 i = 0; i < data.length; i++) {
            (bool success, bytes memory result) = address(this).delegatecall(
                data[i]
            );
            if (success) {
                results[i] = result;
            }
        }
        return results;
    }

    function couldRedeem(uint256 tokenId, uint256[] calldata durationIds)
        public
        view
        virtual
        returns (bool)
    {
        require(isVNft(tokenId), 'not vNFT');
        DoNftInfo storage info = doNftMapping[tokenId];
        Duration storage duration = durationMapping[durationIds[0]];
        if (duration.start > block.timestamp) {
            return false;
        }
        uint64 lastEndTime = duration.end;
        for (uint256 index = 1; index < durationIds.length; index++) {
            require(
                info.durationList.contains(durationIds[index]),
                string(abi.encodePacked('not contails', durationIds[index]))
            );
            duration = durationMapping[durationIds[index]];
            if (lastEndTime + 1 == duration.start) {
                lastEndTime = duration.end;
            }
        }
        return lastEndTime == type(uint64).max;
    }

    function redeem(uint256 tokenId, uint256[] calldata durationIds)
        public
        virtual
    {
        require(
            _isApprovedOrOwner(_msgSender(), tokenId),
            'ERC721: transfer caller is not owner nor approved'
        );
        require(couldRedeem(tokenId, durationIds), 'cannot redeem');
        DoNftInfo storage info = doNftMapping[tokenId];
        ERC721(oNftAddress).safeTransferFrom(
            address(this),
            ownerOf(tokenId),
            info.oid
        );
        _burnVNft(tokenId);
        emit Redeem(info.oid, tokenId);
    }
}
