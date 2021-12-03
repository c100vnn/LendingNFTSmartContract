import { assert, expect } from 'chai'
import { ethers } from 'hardhat'
import { IERC721, NFT, NFTMarket } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BigNumber, BigNumberish } from '@ethersproject/bignumber'

const _BN = (str: string | number) => ethers.BigNumber.from(str)
describe('NFTMarket', function () {
  let [owner, buyer, seller]: SignerWithAddress[] = []
  let market: NFTMarket
  let nft: NFT
  let nftContractAddress: string
  let listingPrice: BigNumber
  let auctionPrice: BigNumber
  beforeEach(async () => {
    // Initialize contract instances
    ;[owner, buyer, seller] = await ethers.getSigners()
    const Market = await ethers.getContractFactory('NFTMarket')
    market = await Market.connect(seller).deploy()
    await market.deployed()
    const marketAddress = market.address

    const NFTToken = await ethers.getContractFactory('NFT')
    nft = await NFTToken.connect(owner).deploy(marketAddress)
    await nft.connect(owner).deployed()
    nftContractAddress = nft.address

    listingPrice = await market.getListingPrice()

    auctionPrice = ethers.utils.parseUnits('1', 'ether')
  })
  describe('Get sell history', async function () {
    beforeEach(async () => {
      let endBlock: BigNumberish = _BN('15000')
      const newToken = await nft.createToken(
        'https://www.mytokenlocation.com',
        1,
        99,
        1000,
        1000,
        50,
        200
      )
      await market
        .connect(owner)
        .createMarketItem(
          nftContractAddress,
          0,
          auctionPrice,
          auctionPrice,
          endBlock,
          { value: listingPrice }
        )
    })
    it('get sell history of token', async () => {
      const item = await market.getMarketItem(0)
      await market
        .connect(buyer)
        .buyDirectly(item.tokenId, { value: auctionPrice })
      const sellHistories = await market.fetchSellHistoryOfToken(item.tokenId)
      assert.equal(sellHistories.length, 1, 'there is one sell history')
    })
  })
  describe('Cancel market item', async function () {
    beforeEach(async () => {
      let endBlock: BigNumberish = _BN('15000')
      const newToken = await nft.createToken(
        'https://www.mytokenlocation.com',
        1,
        99,
        1000,
        1000,
        50,
        200
      )
      await market
        .connect(owner)
        .createMarketItem(
          nftContractAddress,
          0,
          auctionPrice,
          auctionPrice,
          endBlock,
          { value: listingPrice }
        )
    })
    it('revert:sender must be the seller', async () => {
      const item = await market.getMarketItem(0)
      await expect(
        market.connect(buyer).cancelMarketItem(item.itemId)
      ).to.be.revertedWith('sender must be the seller')
    })
    it('revert:item has been sold', async () => {
      const item = await market.getMarketItem(0)
      await market
        .connect(buyer)
        .buyDirectly(item.tokenId, { value: auctionPrice })
      await expect(
        market.connect(owner).cancelMarketItem(item.tokenId)
      ).to.be.revertedWith('item has been sold')
    })
    it('revert:item has been cancelled', async () => {
      const item = await market.getMarketItem(0)
      await market.connect(owner).cancelMarketItem(item.itemId)
      await expect(
        market.connect(owner).cancelMarketItem(item.itemId)
      ).to.be.revertedWith('item has been cancelled')
    })
    it('cancel 1 market item', async () => {
      let endBlock: BigNumberish = _BN('15000')
      // create new token
      await nft
        .connect(owner)
        .createToken(
          'https://www.mytokenlocation2.com',
          1,
          90,
          600,
          400,
          50,
          100
        )
      // owner create market item for new token, mark owner as seller
      await market
        .connect(owner)
        .createMarketItem(
          nftContractAddress,
          1,
          auctionPrice,
          auctionPrice,
          endBlock,
          { value: listingPrice }
        )
      let item = await market.getMarketItem(1)
      // get owner balance before cancel market item
      const balanceBeforeCancel = await ethers.provider.getBalance(
        owner.address
      )
      // owner cancel market item
      const txCancel = await market.connect(owner).cancelMarketItem(item.itemId)
      const tx = await ethers.provider.getTransaction(txCancel.hash)
      const txReceipt = await ethers.provider.getTransactionReceipt(
        txCancel.hash
      )
      // get transaction fee
      const fee = txReceipt.gasUsed.mul(_BN((tx.gasPrice as any).toString()))
      const balanceAfterCancel = await ethers.provider.getBalance(owner.address)
      item = await market.getMarketItem(1)
      assert.equal(item.isCanceled, true, 'isCanceled is set to true')
      assert.equal(
        balanceAfterCancel.toString(),
        balanceBeforeCancel.add(listingPrice).sub(fee).toString(),
        'owner balance before cancel equals to owner balance after cancel plus ' +
          'listing price with the loss for transaction fee'
      )
    })
  })
})
