import { assert, expect } from 'chai'
import { ethers } from 'hardhat'
import { NFT, NFTMarket } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import Web3 from 'web3';
const web3 = new Web3('ws://localhost:8546');
describe('Create market item', function () {
  let [owner, buyer, seller]: SignerWithAddress[] = []
  let market: NFTMarket
  let nft: NFT
  let nftContractAddress: string
  let listingPrice: any
  const minPrice = ethers.utils.parseUnits('1', 'ether')
  const maxPrice = ethers.utils.parseUnits('10', 'ether')
  let currentBlock: number
  beforeEach(async () => {
    // Initialize contract instances
    const ganache = require("ganache-core");
    const web3 = new Web3(ganache.provider());
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
    listingPrice = {
      value: await market.getListingPrice()
    }
    const provider = ethers.getDefaultProvider();
   currentBlock = await provider.getBlockNumber()
  })

  it("Should revert if order fee != listing price ", async function () {
    await expect(market.connect(owner).createMarketItem(nftContractAddress, 0, minPrice, maxPrice, currentBlock + 100, { value: 10 }))
      .to
      .be
      .revertedWith('Order fee must be equal to listing price');
  })

  it("Should revert if min price > max price", async function () {
    const minPrice = ethers.utils.parseUnits('1', 'ether')
    const maxPrice = ethers.utils.parseUnits('10', 'ether')
    //const createTx = await ;
    await expect(market.createMarketItem(nftContractAddress, 0, maxPrice, minPrice, currentBlock + 100, listingPrice))
      .to
      .be
      .revertedWith('max price must be greater than min price');
  })
  it("Should revert if min price <= 0", async function () {
    const minPrice = ethers.utils.parseUnits('1', 'ether')
    const maxPrice = ethers.utils.parseUnits('10', 'ether')
    //const createTx = await ;
    await expect(market.createMarketItem(nftContractAddress, 0, 0, maxPrice, currentBlock + 100, listingPrice))
      .to
      .be
      .reverted;
  })
  it("Should create item correctly if value is valid and token is existed", async function () {
    const minPrice = ethers.utils.parseUnits('1', 'ether')
    const maxPrice = ethers.utils.parseUnits('10', 'ether')
    console.time("DONE_CREATE_ITEM")
    let createMarketItemTx = await market.connect(owner).createMarketItem(nftContractAddress, 0, minPrice, maxPrice, currentBlock + 100, listingPrice)
    console.timeEnd("DONE_CREATE_ITEM")

    let items: any = await market.fetchMarketItems()
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

    expect(items.length).to.equal(1)

    await expect(createMarketItemTx).to.emit(market, 'MarketItemCreated')
      .withArgs(nft.address, 0, 0, owner.address, minPrice, maxPrice, currentBlock+ 100);
  })
})