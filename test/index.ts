import { assert } from 'chai'
import { ethers } from 'hardhat'
import { NFT, NFTMarket } from 'types'

describe("NftContract", async function () {
  let marketAddress: string
  let market: NFTMarket
  let nft: NFT
  beforeEach(async () => {
    const Market = await ethers.getContractFactory("NFTMarket")
    market = await Market.deploy()
    await market.deployed()
    marketAddress = market.address
    const NFT = await ethers.getContractFactory("NFT")
    nft = await NFT.deploy(marketAddress)
    await nft.deployed()
  })
  it("Should create and execute market sales", async function () {
    const createTx = await nft.createToken("Bug", 1, 1, 1, 1, 1, 1)
    assert.equal((await nft.tokenDetails(0)).class, 1, "class must equal to Beast")
    assert.equal((await nft.tokenDetails(0)).level.toNumber(), 1, "level must equal to 1")
    assert.equal((await nft.tokenDetails(0)).heath.toNumber(), 1, "heath must equal to 1 ")
    assert.equal((await nft.tokenDetails(0)).skill.toNumber(), 1, "speed must equal to 1")
    assert.equal((await nft.tokenDetails(0)).speed.toNumber(), 1, "skill must equal to 1")
    assert.equal((await nft.tokenDetails(0)).morale.toNumber(), 1, "morale must equal to 1")

  })
  it("Uplevel and Update Status", async function () {
    const createTx = await nft.createToken("Bug", 1, 1, 1, 1, 1, 1)
    const fee = await nft.setLevelUpFee(1)
    const uplv = await nft.upgradeLevel(0, { value: 1 })
    assert.equal((await nft.tokenDetails(0)).class, 1, "class must equal to Beast")
    assert.equal((await nft.tokenDetails(0)).level.toNumber(), 2, "level must equal to 2")
    assert.equal((await nft.tokenDetails(0)).heath.toNumber(), 2, "heath must equal to 2 ")
    assert.equal((await nft.tokenDetails(0)).skill.toNumber(), 2, "speed must equal to 2")
    assert.equal((await nft.tokenDetails(0)).speed.toNumber(), 2, "skill must equal to 2")
    assert.equal((await nft.tokenDetails(0)).morale.toNumber(), 2, "morale must equal to 2")
  })
})
