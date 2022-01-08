import { assert, expect } from 'chai'
import { ethers, network } from 'hardhat'
import { FarmFinanceNFT, FarmFinance } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import Web3 from 'web3';
import { BigNumber } from 'ethers';
const web3 = new Web3('ws://localhost:8546');
describe('NFT contract', function () {

    let [owner, accountA, accountB]: SignerWithAddress[] = []
    let nft: FarmFinanceNFT
    let token: FarmFinance
    let nftAddress: string
    let tokenAddress: string
    let reserveAmount: string = "10000000000000000000000000" // 10000000*10^18
    let level1Price: BigNumber = ethers.utils.parseUnits("1000", "ether")
    let level2Price: BigNumber = ethers.utils.parseUnits("3000", "ether")
    let totalBalance: BigNumber = ethers.utils.parseUnits('200000000', "ether")
    let sellAmount: BigNumber = ethers.utils.parseUnits('100', "ether")
    beforeEach(async () => {
        [owner, accountA, accountB] = await ethers.getSigners()
        const Token = await ethers.getContractFactory('FarmFinance')
        token = await Token.deploy()
        await token.deployed()
        tokenAddress = await token.address

        const Nft = await ethers.getContractFactory('FarmFinanceNFT')
        nft = await Nft.deploy(tokenAddress)
        await nft.deployed()
        nftAddress = nft.address
        expect(await token.balanceOf(owner.address)).to.be.equal(totalBalance)


    })
    describe('#openSeedBox', () => {
        // beforeEach(async () => {
        //     await token.transfer(reserveAddress, reserveAmount)
        // })
        it("should revert if level is out of range", async function () {
            await token.approve(nftAddress, level2Price)
            await expect(nft.openSeedBox(2)).to.be
                .reverted
        })
        it("should open seed box correctly at level 1 and level 2", async function () {
            await token.approve(nftAddress, level1Price)
            let openTx = await nft.openSeedBox(0)
            let blockTime = await ethers.provider.getBlock
            await expect(openTx).to.be.emit(nft, "SeedBoxOpened").withArgs(0, owner.address, blockTime)
            expect(await token.balanceOf(owner.address)).to.be.equal(totalBalance.sub(level1Price))
            expect(await token.balanceOf(nftAddress)).to.be.equal(level1Price)
            expect(await nft.ownerOf(0)).to.be.equal(owner.address)

            await token.approve(nftAddress, level2Price)
            let openTx2 = await nft.openSeedBox(1)
            let blockTime2 = await ethers.provider.getBlock
            await expect(openTx2).to.be.emit(nft, "SeedBoxOpened").withArgs(1, owner.address, blockTime2)
            expect(await token.balanceOf(owner.address)).to.be.equal(totalBalance.sub(level1Price).sub(level2Price))
            expect(await token.balanceOf(nftAddress)).to.be.equal(level1Price.add(level2Price))
            expect(await nft.ownerOf(1)).to.be.equal(owner.address)
        })
    })
    describe("#createMarketItem", () => {
        beforeEach(async () => {
            await token.approve(nftAddress, level1Price)
            let openTx = await nft.openSeedBox(0)
        })
        it("user must own nft", async function () {
            await expect(nft.connect(accountA).createMarketItem(0, 100)).to.be.revertedWith("ERC721: transfer caller is not owner nor approved")
        })
        it("price must > 0", async function () {
            nft.approve(nftAddress, 0)
            await expect(nft.createMarketItem(0, 0)).to.be.revertedWith("")
        })
        it("should create market item correctly", async function () {
            expect(await nft.balanceOf(owner.address)).to.be.equal(1)
            expect(await nft.balanceOf(nftAddress)).to.be.equal(0)
            expect(await nft.ownerOf(0)).to.be.equal(owner.address)
            // await nft.approve(nftAddress, 0)
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            let blockTime = await ethers.provider.getBlock
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            await expect(createMarketItemTx).to.be.emit(nft, "MarketItemCreated").withArgs(0, 0, sellAmount, owner.address, blockTime)
        })
        it("should can't create market item if token has been on selling", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            let blockTime = await ethers.provider.getBlock
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            await expect(createMarketItemTx).to.be.emit(nft, "MarketItemCreated").withArgs(0, 0, sellAmount, owner.address, blockTime)
            await expect(nft.createMarketItem(0, sellAmount)).to.be.revertedWith("ERC721: transfer caller is not owner nor approved")
        })
    })
    describe("#cancelMarketItem", () => {
        beforeEach(async () => {
            await token.approve(nftAddress, level1Price)
            let openTx = await nft.openSeedBox(0)
            await token.transfer(accountA.address, sellAmount)
            expect(await token.balanceOf(accountA.address)).to.be.equal(sellAmount)
        })
        it("should revert if sender isn't owner", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            await expect(nft.connect(accountA).cancelMarketItem(0)).to.be.revertedWith("sender must be the seller")
        })
        it("should revert if item has been sold", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            await token.connect(accountA).approve(nftAddress,sellAmount)
            console.log('--------------------------market:',await nft.idToMarketItem(0))
            await nft.connect(accountA).buyMarketItem(0);
            await expect(nft.connect(accountA).cancelMarketItem(0)).to.be.revertedWith("sender must be the seller")
        })
        it("should revert if item has been canceled", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            await nft.cancelMarketItem(0)
            await expect(nft.connect(accountA).cancelMarketItem(0)).to.be.revertedWith("item has been sold")
        })
        it("should cancel item correctly", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            let cancelMarketItemTx = await nft.cancelMarketItem(0)
            let blockTime = await ethers.provider.getBlock
            await expect(cancelMarketItemTx).to.be.emit(nft, "MarketItemCanceled").withArgs(
                0,
                0,
                sellAmount,
                owner.address,
                blockTime
            )
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
        })
    })
    describe("#buyMarketItem", () => {
        it("should revert if asker is owner", async function () {
            
        })
        it("should revert if item has been sold", async function () {

        })
        it("should revert if item has been canceled", async function () {

        })  
        it("should buy correctly", async function () {

        })
    })
    describe("#withdrawToken", () => {
        it("should revert if contract balance =0", async function () {

        })
        it("withdraw correctly", async function () {

        })
    })
})