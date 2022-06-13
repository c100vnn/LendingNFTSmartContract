//SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.4;

import "erc721a/contracts/ERC721A.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";
import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

contract Loc is ERC721A, AccessControl, Pausable {
    event DutchAuctionMinted(address owner, uint256 pricePaid, uint16 quantity);
    bytes32 public constant DEV_ROLE = keccak256("DEV_ROLE");
    string private _baseTokenURI;

    //Base Extension
    string public constant baseExtension = ".json";
    bool public isMintActive = true;
    struct NumberMinted {
        uint16 numberPrivateMinted;
        uint16 numberPublicMinted;
        uint16 numberDutchAuctionMinted;
    }
    uint256 public totalMetadataRecords = 10000;
    uint256 public randomNum;
    uint256 public publicMintStartingTimestamp;
    uint256 public privateMintStartingTimestamp;
    uint16 public immutable maxPublicSupply;
    uint16 public immutable maxPrivateSupply;
    uint16 public totalPrivateMinted;
    uint16 public totalPublicMinted;
    uint8 public immutable maxPrivateMintPerWallet;
    uint8 public immutable maxPublicMintPerWallet;
    uint8 public immutable maxPrivateMintPerTx;
    uint8 public immutable maxPublicMintPerTx;
    uint256 public immutable privateMintPrice;
    uint256 public immutable publicMintPrice;

    bool public revealed;
    bytes32 public merkleRoot;
    // Mapping owner address to number private minted
    mapping(address => NumberMinted) private _numberTokenMinted;

    //Starting price
    uint256 public immutable dutchAuctionStartingPrice;

    //Ending price
    uint256 public immutable dutchAuctionEndingPrice;

    //Decrease price every frequency.
    uint256 public immutable dutchAuctionDecrement;

    //decrement price every numbers seconds.
    uint256 public immutable dutchAuctionDecrementFrequence;

    //The final auction price.
    uint256 public dutchAuctionFinalPrice;

    //The quantity for DA mint.
    uint16 public immutable maxDutchAuctionSupply;

    //the quantity for max mint nft per tx
    uint8 public immutable maxDutchAuctionMintPerTx;

    //the quantity for max mint nft per wallet in dutch auction
    uint8 public immutable maxDutchAuctionMintPerWallet;

    //the total for nft minted
    uint16 public totalDutchAuctionMinted;

    constructor(
        uint256[] memory publicProps_,
        uint256[] memory privateProps_,
        uint256[] memory dutchProps_,
        uint256 publicMintStartingTimestamp_,
        uint256 privateMintStartingTimestamp_,
        address adminAddress
    ) ERC721A("Loc", "loc") {
        _setupRole(DEFAULT_ADMIN_ROLE, adminAddress);
        _setupRole(DEV_ROLE, adminAddress);
        _setupRole(DEV_ROLE, _msgSender());
        require(publicMintStartingTimestamp_ < privateMintStartingTimestamp_);
        publicMintStartingTimestamp = publicMintStartingTimestamp_;
        privateMintStartingTimestamp = privateMintStartingTimestamp_;
        //phare public mint
        maxPublicSupply = uint16(publicProps_[0]);
        maxPublicMintPerWallet = uint8(publicProps_[1]);
        maxPublicMintPerTx = uint8(publicProps_[2]);
        publicMintPrice = publicProps_[3];
        //phare private mint
        maxPrivateSupply = uint16(privateProps_[0]);
        maxPrivateMintPerWallet = uint8(privateProps_[1]);
        maxPrivateMintPerTx = uint8(privateProps_[2]);
        privateMintPrice = privateProps_[3];
        //phare auction mint
        maxDutchAuctionSupply = uint16(dutchProps_[0]);
        maxDutchAuctionMintPerWallet = uint8(dutchProps_[1]);
        maxDutchAuctionMintPerTx = uint8(dutchProps_[2]);
        dutchAuctionStartingPrice = dutchProps_[3];
        dutchAuctionEndingPrice = dutchProps_[4];
        dutchAuctionDecrement = dutchProps_[5];
        dutchAuctionDecrementFrequence = dutchProps_[6];
    }
    modifier whenPublicMintIsActive() {
        require(isMintActive, "Mint is not active");
        require(_isPublicMintActive(), "Public mint is not active");
        _;
    }

    modifier whenPrivateMintIsActive() {
        require(isMintActive, "Mint is not active");
        require(_isPrivateMintActive(), "Private mint is not active");
        _;
    }

    function isPublicMintActive() external view returns (bool) {
        return _isPublicMintActive();
    }

    function _isPublicMintActive() internal view returns (bool) {
        return (block.timestamp > publicMintStartingTimestamp &&
            block.timestamp < privateMintStartingTimestamp);
    }

    function isPrivateMintActive() external view returns (bool) {
        return _isPrivateMintActive();
    }

    function _isPrivateMintActive() internal view returns (bool) {
        return (block.timestamp > privateMintStartingTimestamp);
    }

    function startOrStopMint()
        external
        onlyRole(DEV_ROLE)
    {
        isMintActive = !isMintActive;
    }

    function setTotalMetadataRecords(uint256 totalMetadataRecords_)
        external
        onlyRole(DEV_ROLE)
    {
        require(
            totalMetadataRecords_ > 0,
            "Total meta data records must greater than 0"
        );
        totalMetadataRecords = totalMetadataRecords_;
    }

    function setStartTime(
        uint256 publicMintStartingTimestamp_,
        uint256 privateMintStartingTimestamp_
    ) external onlyRole(DEV_ROLE) {
        require(publicMintStartingTimestamp_ < privateMintStartingTimestamp_);
        publicMintStartingTimestamp = publicMintStartingTimestamp_;
        privateMintStartingTimestamp = privateMintStartingTimestamp_;
    }

    function setMerkleRoot(bytes32 merkleRoot_)
        external
        onlyRole(DEV_ROLE)
    {
        merkleRoot = merkleRoot_;
    }

    function privateMint(uint16 quantity_, bytes32[] calldata merkleProof_)
        external
        payable
        whenPrivateMintIsActive
    {
        require(
            msg.value >= privateMintPrice * quantity_,
            "Ether value sent is not correct"
        );
        require(quantity_ > 0, "Must mint at least one");
        require(
            quantity_ <= maxPrivateMintPerTx,
            "Quantity should not exceed maxPrivateMintPerTx"
        );
        require(
            totalPrivateMinted + quantity_ <= maxPrivateSupply,
            "Exceed max supply"
        );
        require(
            _numberTokenMinted[_msgSender()].numberPrivateMinted + quantity_ <=
                maxPrivateMintPerWallet,
            "Exceed max number of token can mint per wallet"
        );
        require(
            _verifyProof(merkleProof_, _msgSender()),
            "Sender address is not in whitelist"
        );

        _numberTokenMinted[_msgSender()].numberPrivateMinted += quantity_;
        totalPrivateMinted += quantity_;
        _safeMint(_msgSender(), quantity_);
    }

    function _verifyProof(bytes32[] calldata merkleProof_, address leaf_)
        internal
        view
        returns (bool)
    {
        return
            MerkleProof.verify(
                merkleProof_,
                merkleRoot,
                keccak256(abi.encodePacked(leaf_))
            );
    }

    function publicMint(uint16 quantity_)
        external
        payable
        whenPublicMintIsActive
    {
        require(
            msg.value >= publicMintPrice * quantity_,
            "Ether value sent is not correct"
        );
        require(quantity_ > 0, "Must mint at least one");
        require(
            quantity_ <= maxPublicMintPerTx,
            "Quantity should not exceed maxPublicMintPerTx"
        );
        require(
            totalPublicMinted + quantity_ <= maxPublicSupply,
            "Exceed max supply"
        );
        require(
            _numberTokenMinted[_msgSender()].numberPublicMinted + quantity_ <=
                maxPublicMintPerWallet,
            "Exceed max number of token can mint per wallet"
        );

        _numberTokenMinted[_msgSender()].numberPublicMinted += quantity_;
        totalPublicMinted += quantity_;
        _safeMint(_msgSender(), quantity_);
    }

    function dutchAuctionMint(uint16 quantity_)
        external
        payable
        whenPublicMintIsActive
    {
        uint256 currentPrice = dutchAuctionCurrentPrice();
        require(
            msg.value >= quantity_ * currentPrice,
            "Ether value sent is not correct"
        );
        require(quantity_ > 0, "Must mint at least one beta");
        require(
            quantity_ <= maxDutchAuctionMintPerTx,
            "Quantity should not exceed maxDutchAuctionMintPerTx"
        );
        require(
            totalDutchAuctionMinted + quantity_ <= maxDutchAuctionSupply,
            "Exceed max supply"
        );
        require(
            _numberTokenMinted[_msgSender()].numberDutchAuctionMinted +
                quantity_ <=
                maxDutchAuctionMintPerWallet,
            "Exceed max number of token can mint per wallet"
        );

        _numberTokenMinted[_msgSender()].numberDutchAuctionMinted += quantity_;
        totalDutchAuctionMinted += quantity_;

        if (totalDutchAuctionMinted == maxDutchAuctionSupply) {
            dutchAuctionFinalPrice = currentPrice;
        }

        _safeMint(_msgSender(), quantity_);

        emit DutchAuctionMinted(_msgSender(), msg.value, quantity_);
    }

    function dutchAuctionCurrentPrice() public view returns (uint256) {
        require(
            block.timestamp >= publicMintStartingTimestamp,
            "Dutch Auction has not started"
        );

        if (dutchAuctionFinalPrice > 0) return dutchAuctionFinalPrice;

        //Seconds since we started
        uint256 timeSinceStart = block.timestamp - publicMintStartingTimestamp;

        //How many decrements should've happened since that time
        uint256 decrementsSinceStart = timeSinceStart /
            dutchAuctionDecrementFrequence;

        //How much eth to remove
        uint256 totalDecrement = decrementsSinceStart * dutchAuctionDecrement;

        //If how much we want to reduce is greater or equal to the range, return the lowest value
        if (
            totalDecrement >=
            dutchAuctionStartingPrice - dutchAuctionEndingPrice
        ) {
            return dutchAuctionEndingPrice;
        }

        //If not, return the starting price minus the decrement.
        return dutchAuctionStartingPrice - totalDecrement;
    }

    function getMintedDetail(address owner)
        public
        view
        returns (NumberMinted memory)
    {
        return _numberTokenMinted[owner];
    }

    function verifyProof(bytes32[] calldata merkleProof_, address leaf_)
        external
        view
        returns (bool)
    {
        return _verifyProof(merkleProof_, leaf_);
    }

    // // metadata / reveal

    function reveal() external onlyRole(DEV_ROLE) {
        revealed = true;
        randomNum = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _msgSender()))) % totalMetadataRecords;
    }

    function emergencySetRandomNumber()
        external
        onlyRole(DEV_ROLE)
    {
        randomNum = uint256(keccak256(abi.encodePacked(block.difficulty, block.timestamp, _msgSender()))) % totalMetadataRecords;
    }

    function updateBaseTokenURI(string memory baseTokenURI_)
        public
        onlyRole(DEV_ROLE)
    {
        _baseTokenURI = baseTokenURI_;
    }

    function tokenURI(uint256 _tokenId)
        public
        view
        override
        returns (string memory)
    {
        require(
            _exists(_tokenId),
            "ERC721Metadata: URI query for nonexistent token"
        );
        if (!revealed) return _baseTokenURI;
        return
            string(
                abi.encodePacked(
                    _baseTokenURI,
                    Strings.toString(
                        (_tokenId + randomNum) % totalMetadataRecords
                    ),
                    baseExtension
                )
            );
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _baseTokenURI;
    }

    //withdraw ether
//    function withdraw() external onlyRole(DEFAULT_ADMIN_ROLE) {
//        uint256 balance = address(this).balance;
//        require(balance > 0, "There is no ETH to withdraw");
//        Address.sendValue(payable(_msgSender()), balance);
//    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        override(ERC721A, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
