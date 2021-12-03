import { assert, expect } from 'chai'
import { ethers } from 'hardhat'
import { NFT, NFTMarket } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

describe('Create market item', function () {
    let [owner, buyer, seller]: SignerWithAddress[] = []
    let market: NFTMarket
    let nft: NFT
    let nftContractAddress: string
    const minPrice = ethers.utils.parseUnits('1', 'ether')
    const maxPrice = ethers.utils.parseUnits('10', 'ether')
    beforeEach(async () => {
        // Initialize contract instances
        ;[owner, buyer, seller] = await ethers.getSigners()
        const Market = await ethers.getContractFactory('NFTMarket')
        market = await Market.deploy()
        await market.deployed()
        const marketAddress = market.address

        const NFTToken = await ethers.getContractFactory('NFT')
        nft = await NFTToken.connect(owner).deploy(marketAddress)
        await nft.deployed()
        await nft.createToken("", 1, 1, 1, 1, 1, 1)
        nftContractAddress = nft.address
        let listingPrice = {
            value: await market.getListingPrice()
        }
        const minPrice = ethers.utils.parseUnits('1', 'ether')
        const maxPrice = ethers.utils.parseUnits('10', 'ether')
        const provider = ethers.getDefaultProvider();
        const currentBlock = await provider.getBlockNumber()
        await market.createMarketItem
            (nftContractAddress, 0, minPrice, maxPrice, currentBlock + 100, listingPrice)

    })
    it("Should revert if asker is owner ", async function () {

        await expect(market.buyDirectly(0, {
            value: maxPrice
        })).to.be.revertedWith('asker must not be owner')
    })
    it("Should revert if item has been canceled ", async function () {
        market.cancelMarketItemAuction(0);
        await expect(market.connect(buyer).buyDirectly(0, {
            value: maxPrice
        })).to.be.revertedWith('Item has been cancelled')
    })
    it("Should revert if item has been sold ", async function () {
        market.connect(seller).buyDirectly(0, { value: maxPrice });
        //market.cancelMarketItemAuction(0);
        await expect(market.connect(buyer).buyDirectly(0, {
            value: maxPrice
        })).to.be.revertedWith('item has been sold')
    })
    it("Should revert if amount not equal to max price ", async function () {
        await expect(market.connect(buyer).buyDirectly(0, {
            value: minPrice
        })).to.be.revertedWith('Price must equal to max price to buy directly')
    })  
    it("Should buy correctly", async function () {
        let buyTx = await market.connect(buyer).buyDirectly(0, {
            value: maxPrice
        })
        let items: any = await market.connect(buyer).fetchMyNFTs(buyer.address)
        items = await Promise.all(items.map(async (i: any) => {
            return {
              nftContract: i.nftContract,
              itemId: i.itemId.toNumber(),
              tokenId: i.tokenId.toNumber(),
              seller: i.seller,
              buyer: i.buyer,
              minPrice: i.minPrice,
              maxPrice: i.maxPrice,
              currentPrice: i.currentPrice.toString(),
              endBlock: i.endBlock.toNumber(),
              sold: i.sold,
              isCanceled: i.isCanceled,
              offerCount: i.offerCount
            }
          }))
        console.log(items)
          await expect(buyTx).to.emit(market, 'ItemBuyDirectly')
          .withArgs(nftContractAddress,0,0,buyer.address)
    })
})