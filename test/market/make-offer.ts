import { assert, expect } from 'chai'
import { ethers } from 'hardhat'
import { NFT, NFTMarket } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

describe('make offer', function () {
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
        const provider = ethers.getDefaultProvider()
        const currentBlock = await provider.getBlockNumber()
        await market.createMarketItem
            (nftContractAddress, 0, minPrice, maxPrice, currentBlock + 100, listingPrice)
    })

    it("Should revert if asker is owner ", async function () {
        await expect(market.makeOffer(0, {
            value: 1
        })).to.be.revertedWith('asker must not be owner')
    })
    it("Should revert if item has been sold", async function () {
        market.connect(buyer).buyDirectly(0, { value: maxPrice });
        await expect(market.connect(seller).makeOffer(0, {
            value: ethers.utils.parseUnits('2', 'ether')
        })).to.be.revertedWith('item has been sold')
    })
    it("Should revert if item has been canceled", async function () {
        market.cancelMarketItemAuction(0);
        await expect(market.connect(buyer).makeOffer(0, {
            value: ethers.utils.parseUnits('2', 'ether')
        })).to.be.revertedWith('Item has been cancelled')
    })
    it("Should revert item if offer < min price", async function () {
        await expect(market.connect(buyer).makeOffer(0, {
            value: ethers.utils.parseUnits('0.1', 'ether')
        })).to.be.revertedWith('Offer must greater than min price')
    })
    it("Should revert item if offer > max price", async function () {
        await expect(market.connect(buyer).makeOffer(0, {
            value: ethers.utils.parseUnits('11', 'ether')
        })).to.be.revertedWith('Offer must less than max price')
    })
    it("Should revert item if offer < current price", async function () {
        await market.connect(seller).makeOffer(0, {
            value: ethers.utils.parseUnits('9', 'ether')
        })
        await expect(market.connect(buyer).makeOffer(0, {
            value: ethers.utils.parseUnits('8', 'ether')
        })).to.be.revertedWith('Offer must greater than current price')
    })
    it("Should make offer correctly", async function () {
        let makeOfferTx = await market.connect(buyer).makeOffer(0, {
            value: ethers.utils.parseUnits('9', 'ether')
        })
        let offers: any = await market.fetchOffersOfItem(0)
        
        offers = await Promise.all(offers.map(async (i: any) => {
            return {
                offerId: i.offerId.toNumber(),
                asker: i.asker,
                amount: i.amount.toString(),
                refundable: i.refundable,
                blockTime: i.blockTime.toNumber(),
            }
        }))
        console.log(offers)
        expect(offers.length).to.equal(1)
        console.log(nft.address)
        await expect(makeOfferTx).to.emit(market, 'OfferPlaced')
       .withArgs(nftContractAddress, 0, 0, 0, buyer.address, ethers.utils.parseUnits('9', 'ether'), offers[0].blockTime);
    })
})