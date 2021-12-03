import { assert, expect } from 'chai'
import { ethers } from 'hardhat'
import { NFT, NFTMarket } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'

describe('Create lend item', function () {
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
        lendBlockDuration = await provider.getBlockNumber()
    })

    it("should revert if order fee != listing price", async function () {
        await expect(market.connect(owner).lend(nftContractAddress, 0,priceLend, lendBlockDuration + 100, { value: 10 }))
            .to
            .be
            .revertedWith("Order fee must be equal to listing price")
    })

    it("should create lend item correctly", async function () {
        const priceLend = ethers.utils.parseUnits('1', 'ether')
        console.time("Done Create item")
        let lendTx = await market.connect(owner).lend(nftContractAddress, 0,priceLend, lendBlockDuration + 100, listingPrice)
        let createLendItem = await lendTx.wait()
        console.timeEnd("Done Create item")

        let lend: any = await market.fetchAllLendItem()
        
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
        console.log(lends.length)

        expect(lend.length).to.equal(1)
        await expect(lendTx).to.emit(market, "LendItemCreated")
            .withArgs(nftContractAddress, 0, 0, owner.address, priceLend, lendBlockDuration+ 100)
    })
})