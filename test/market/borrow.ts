import { assert, expect } from 'chai'
import { ethers } from 'hardhat'
import { NFT, NFTMarket } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

describe('Should borrow is correctly', function () {
    let [owner, lender, borrower]: SignerWithAddress[] = []
    let market: NFTMarket
    let nft: NFT
    let nftContractAddress: string
    let listingPrice: any
    const priceLend = ethers.utils.parseUnits('1', 'ether')
    let lendBlockDuration: number
    beforeEach(async () => {
        [owner, lender, borrower] = await ethers.getSigners()
        const Market = await ethers.getContractFactory('NFTMarket')
        market = await Market.deploy()
        await market.deployed()
        const marketAddress = market.address

        const NFTToken = await ethers.getContractFactory('NFT')
        nft = await NFTToken.connect(owner).deploy(marketAddress)
        await nft.deployed()
        await nft.createToken("", 1, 1, 1, 1, 1, 1)
        nftContractAddress = nft.address
        listingPrice = {
        value: await market.getListingPrice()
        }
        const priceLend = ethers.utils.parseUnits('1', 'ether')
        const provider = ethers.getDefaultProvider();
        const lendBlockDuration = await provider.getBlockNumber()
        await market.connect(owner).lend(nftContractAddress, 0,priceLend, lendBlockDuration + 100, listingPrice)
    })
    it("Should revert if asker is owner", async function () {
        await expect(market.borrow(0, {
            value: priceLend
        })).to.be.revertedWith('asker must not be owner')
    })

    it("Should revert if amount not equal to priceLend", async function () {
        await expect(market.connect(borrower).borrow(0, {
            value: ethers.utils.parseUnits('0.1', 'ether')
        })).to.be.revertedWith('Price must equal to priceLend')
    })

    it("Should revert if item has been lent ", async function () {
        market.connect(lender).borrow(0, { value: priceLend });
        await expect(market.connect(borrower).borrow(0, {
            value: priceLend
        })).to.be.revertedWith('item has been lent')
    })

    it("Should borrow correctly", async function () {
        let borrow = await market.connect(borrower).borrow(0, {
            value: priceLend
        })
        let lend: any = await market.connect(borrower).fetchMyBorrow(borrower.address)
        const lends = lend.map(async (i: any) => {
            return {
                nftContract: i.nftContractAddress,
                itemId: i.itemId.toNumber(),
                tokenId: i.tokenId.toNumber(),
                lender: i.lender,
                buyer: i.buyer,
                priceLend: i.priceLend,
                lent: i.lent,
                paid: i.paid,
                isCanceled: i.isCanceled,
                lendBlockDuration: i.lendBlockDuration
            }
        })
        console.log(lends)
            await expect(borrow).to.emit(market, "ItemBorrow")
                .withArgs(nftContractAddress,0,0,borrower.address)
    })
})