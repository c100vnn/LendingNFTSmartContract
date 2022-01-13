import { assert, expect } from 'chai'
import { ethers, network } from 'hardhat'
import { FarmFinanceNFT, FarmFinance } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import Web3 from 'web3';
import { BigNumber } from 'ethers';
import EthCrypto  from 'eth-crypto';
const web3 = new Web3('ws://localhost:8546');
describe('NFT contract', function () {

    let [owner, accountA, accountB, accountC]: SignerWithAddress[] = []
    let nft: FarmFinanceNFT
    let token: FarmFinance
    let nftAddress: string
    let tokenAddress: string
    let addressZero: string = "0x0000000000000000000000000000000000000000"
    let reserveAmount: string = "10000000000000000000000000" // 10000000*10^18
    let level1Price: BigNumber = ethers.utils.parseUnits("1000", "ether")
    let level2Price: BigNumber = ethers.utils.parseUnits("3000", "ether")
    let totalBalance: BigNumber = ethers.utils.parseUnits('200000000', "ether")
    let sellAmount: BigNumber = ethers.utils.parseUnits('100', "ether")
    beforeEach(async () => {
        [owner, accountA, accountB, accountC] = await ethers.getSigners()
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
            await expect(openTx).to.be.emit(nft, "SeedBoxOpened").withArgs(0, owner.address, blockTime, 0)
            expect(await token.balanceOf(owner.address)).to.be.equal(totalBalance.sub(level1Price))
            expect(await token.balanceOf(nftAddress)).to.be.equal(level1Price)
            expect(await nft.ownerOf(0)).to.be.equal(owner.address)

            await token.approve(nftAddress, level2Price)
            let openTx2 = await nft.openSeedBox(1)
            let blockTime2 = await ethers.provider.getBlock
            await expect(openTx2).to.be.emit(nft, "SeedBoxOpened").withArgs(1, owner.address, blockTime2, 1)
            expect(await token.balanceOf(owner.address)).to.be.equal(totalBalance.sub(level1Price).sub(level2Price))
            expect(await token.balanceOf(nftAddress)).to.be.equal(level1Price.add(level2Price))
            expect(await nft.ownerOf(1)).to.be.equal(owner.address)
        })
    })
    describe('#openSeedBoxWithSignature', () => {
        // beforeEach(async () => {
        //     await token.transfer(reserveAddress, reserveAmount)
        // })
        it("should revert if role not true", async function () {
            let message = "0" + "-" + accountB.address  
            let hash =  ethers.utils.solidityKeccak256(['string'], [message]);
            let signature = await accountB.signMessage(ethers.utils.arrayify(hash))
            await nft.grantRole(ethers.utils.solidityKeccak256(['string'], ["MINTER_ROLE"]) , accountA.address)
            await expect(nft.connect(accountB).openSeedBoxWithSignature(accountB.address, hash, signature)).to.be.reverted

        })
        it("should revert if signature wrong", async function () {
            let message = "0" + "-" + accountB.address  
            let hash =  ethers.utils.solidityKeccak256(['string'], [message]);
            let signature = await accountB.signMessage(ethers.utils.arrayify(hash))
            await nft.grantRole(ethers.utils.solidityKeccak256(['string'], ["MINTER_ROLE"]) , accountA.address)
            await expect(nft.openSeedBoxWithSignature(accountC.address, hash, signature)).to.be.revertedWith('Signature does not match message sender')

        })
        it("should open seed box correctly", async function () {
            let message = "0" + "-" + accountB.address  
            let hash =  ethers.utils.solidityKeccak256(['string'], [message]);
            let signature = await accountB.signMessage(ethers.utils.arrayify(hash))
            await nft.grantRole(ethers.utils.solidityKeccak256(['string'], ["MINTER_ROLE"]) , accountA.address)
            let openTx = await nft.connect(accountA).openSeedBoxWithSignature(accountB.address, hash, signature)
            let blockTime = await ethers.provider.getBlock
            await expect(openTx).to.be.emit(nft, "SeedBoxOpenedWithSignature").withArgs(0, accountB.address , blockTime)
            expect(await nft.ownerOf(0)).to.be.equal(accountB.address)
        })
    })
    describe("#createMarketItem", () => {
        beforeEach(async () => {
            await token.approve(nftAddress, level1Price)
            let openTx = await nft.openSeedBox(0)
        })
        it("user must own nft", async function () {
            await expect(nft.connect(accountA).createMarketItem(0, 100)).to.be.revertedWith("ERC721: transfer of token that is not own")
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
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            expect((await nft.idToMarketItem(0)).buyer).to.be.equal(addressZero)
            expect((await nft.idToMarketItem(0)).tokenId).to.be.equal(0)
            expect((await nft.idToMarketItem(0)).itemId).to.be.equal(0)
            expect((await nft.idToMarketItem(0)).seller).to.be.equal(owner.address)
            expect((await nft.idToMarketItem(0)).price).to.be.equal(sellAmount)
            expect((await nft.idToMarketItem(0)).sold).to.be.equal(false)
            expect((await nft.idToMarketItem(0)).isCanceled).to.be.equal(false)
        })
        it("can't create market item if token has been on selling", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            let blockTime = await ethers.provider.getBlock
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            await expect(createMarketItemTx).to.be.emit(nft, "MarketItemCreated").withArgs(0, 0, sellAmount, owner.address, blockTime)
            await expect(nft.createMarketItem(0, sellAmount)).to.be.revertedWith("ERC721: transfer of token that is not own")
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
            await token.connect(accountA).approve(nftAddress, sellAmount)
            await nft.connect(accountA).buyMarketItem(0);
            await expect(nft.cancelMarketItem(0)).to.be.revertedWith("item has been sold")
        })
        it("should revert if item has been canceled", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            await nft.cancelMarketItem(0)
            await expect(nft.cancelMarketItem(0)).to.be.revertedWith("item has been cancelled")
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
            expect(await nft.ownerOf(0)).to.be.equal(owner.address)
            expect((await nft.idToMarketItem(0)).buyer).to.be.equal(addressZero)
            expect((await nft.idToMarketItem(0)).tokenId).to.be.equal(0)
            expect((await nft.idToMarketItem(0)).itemId).to.be.equal(0)
            expect((await nft.idToMarketItem(0)).seller).to.be.equal(owner.address)
            expect((await nft.idToMarketItem(0)).price).to.be.equal(sellAmount)
            expect((await nft.idToMarketItem(0)).sold).to.be.equal(false)
            expect((await nft.idToMarketItem(0)).isCanceled).to.be.equal(true)

        })
    })
    describe("#buyMarketItem", () => {
        beforeEach(async () => {
            await token.approve(nftAddress, level1Price)
            let openTx = await nft.openSeedBox(0)
            await token.transfer(accountA.address, sellAmount)
            await token.transfer(accountB.address, sellAmount)
            expect(await token.balanceOf(accountA.address)).to.be.equal(sellAmount)
            await token.connect(accountA).approve(nft.address, sellAmount)
            await token.connect(accountB).approve(nft.address, sellAmount)
            expect(await token.allowance(accountA.address, nftAddress)).to.be.equal(sellAmount)
            expect(await token.allowance(accountB.address, nftAddress)).to.be.equal(sellAmount)
        })
        it("should revert if asker is owner", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            await expect(nft.buyMarketItem(0)).to.be.revertedWith('asker must not be owner')
        })
        it("should revert if item has been sold", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)

            await nft.connect(accountA).buyMarketItem(0)
            await expect(nft.connect(accountB).buyMarketItem(0)).to.be.revertedWith('item has been sold')
        })
        it("should revert if item has been canceled", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            await nft.cancelMarketItem(0)
            await expect(nft.connect(accountB).buyMarketItem(0)).to.be.revertedWith('Item has been cancelled')
        })
        it("should buy correctly", async function () {
            let createMarketItemTx = await nft.createMarketItem(0, sellAmount)
            expect(await nft.ownerOf(0)).to.be.equal(nftAddress)
            let buyTx = nft.connect(accountB).buyMarketItem(0);
            let blockTime = await ethers.provider.getBlock
            await expect(buyTx).to.be.emit(nft, "MarketItemBought").withArgs(
                0,
                0,
                sellAmount,
                owner.address,
                accountB.address,
                blockTime
            )
            expect(await nft.ownerOf(0)).to.be.equal(accountB.address)
            expect(await nft.balanceOf(accountB.address)).to.be.equal(1)
            expect(await nft.balanceOf(accountA.address)).to.be.equal(0)
            expect((await nft.idToMarketItem(0)).buyer).to.be.equal(accountB.address)
            expect((await nft.idToMarketItem(0)).tokenId).to.be.equal(0)
            expect((await nft.idToMarketItem(0)).itemId).to.be.equal(0)
            expect((await nft.idToMarketItem(0)).seller).to.be.equal(owner.address)
            expect((await nft.idToMarketItem(0)).price).to.be.equal(sellAmount)
            expect((await nft.idToMarketItem(0)).sold).to.be.equal(true)
            expect((await nft.idToMarketItem(0)).isCanceled).to.be.equal(false)
        })
    })
    describe("#withdrawToken", () => {
        it("should revert if contract balance =0", async function () {
            await expect(nft.withdrawToken()).to.be.revertedWith("contract out of token")
        })
        it("should revert if caller is not owner", async function () {
            await expect(nft.connect(accountB).withdrawToken()).to.be.revertedWith("AccessControl: account 0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc is missing role 0x0000000000000000000000000000000000000000000000000000000000000000")
        })
        it("withdraw correctly", async function () {
            let totalGachaAmount = (level1Price.add(level2Price)).mul(4)
            await token.transfer(accountA.address, totalGachaAmount)
            expect(await token.balanceOf(owner.address)).to.be.equal(totalBalance.sub(totalGachaAmount))

            await token.connect(accountA).approve(nftAddress, level1Price)
            await nft.connect(accountA).openSeedBox(0)
            await token.connect(accountA).approve(nftAddress, level1Price)
            await nft.connect(accountA).openSeedBox(0)
            await token.connect(accountA).approve(nftAddress, level1Price)
            await nft.connect(accountA).openSeedBox(0)
            await token.connect(accountA).approve(nftAddress, level1Price)
            await nft.connect(accountA).openSeedBox(0)
            await token.connect(accountA).approve(nftAddress, level2Price)
            await nft.connect(accountA).openSeedBox(1)
            await token.connect(accountA).approve(nftAddress, level2Price)
            await nft.connect(accountA).openSeedBox(1)
            await token.connect(accountA).approve(nftAddress, level2Price)
            await nft.connect(accountA).openSeedBox(1)
            await token.connect(accountA).approve(nftAddress, level2Price)
            await nft.connect(accountA).openSeedBox(1)
            expect(await token.balanceOf(nftAddress)).to.be.equal(totalGachaAmount)
            let withdrawTx = await nft.withdrawToken()
            expect(await token.balanceOf(owner.address)).to.be.equal(totalBalance)
        })
    })
})