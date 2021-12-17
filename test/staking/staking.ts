import { assert, expect } from 'chai'
import { ethers, network } from 'hardhat'
import { Staking, Reserve, FarmFinance } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import Web3 from 'web3';
import { BigNumber } from 'ethers';
const web3 = new Web3('ws://localhost:8546');
describe('Staking contract', function () {

    let [admin, receiver1, receiver2]: SignerWithAddress[] = []
    let reserve: Reserve
    let token: FarmFinance
    let staking: Staking
    let reserveAddress: string
    let stakingAdress: string
    let tokenAddress: string
    let reserveAmount: string = "10000000000000000000000000" // 10000000*10^18
    beforeEach(async () => {
        const ganache = require("ganache-core");
        const web3 = new Web3(ganache.provider());
        [admin, receiver1, receiver2] = await ethers.getSigners()
        const Token = await ethers.getContractFactory('FarmFinance')
        token = await Token.deploy()
        await token.deployed()
        tokenAddress = await token.address

        const Staking = await ethers.getContractFactory('Staking')
        staking = await Staking.deploy(tokenAddress)
        await staking.deployed()
        stakingAdress = staking.address

        const Reserve = await ethers.getContractFactory('Reserve')
        reserve = await Reserve.deploy(tokenAddress, stakingAdress)
        await reserve.deployed()
        reserveAddress = reserve.address
        await staking.setReserve(reserveAddress)
        await token.transfer(reserveAddress, reserveAmount)
        await expect((await staking.stakePackages(0)).rate).to.be.equal(137)
    })
    describe('#addStakePackage', () => {
        // beforeEach(async () => {
        //     await token.transfer(reserveAddress, reserveAmount)
        // })
        it("should revert if rate = 0", async function () {
            await expect(staking.addStakePackage(0, ethers.utils.parseUnits("500", "ether"), 5)).to.be
                .reverted
        })
        it("should add stake package correctly", async function () {
            await staking.addStakePackage(41, ethers.utils.parseUnits("500", "ether"), 5)
            await expect((await staking.stakePackages(1)).rate).to.be.equal(41)
            await expect((await staking.stakePackages(1)).minStaking).to.be.equal(ethers.utils.parseUnits("500", "ether"))
            await expect((await staking.stakePackages(1)).lockDays).to.be.equal(5)
        })
    })
    describe('#updateStakePackage', () => {
        it("should update stake package correctly", async function () {
            await staking.updateStakePackage(0, 100, ethers.utils.parseUnits("5000", "ether"), 100)
            await expect((await staking.stakePackages(0)).rate).to.be.equal(100)
            await expect((await staking.stakePackages(0)).minStaking).to.be.equal(ethers.utils.parseUnits("5000", "ether"))
            await expect((await staking.stakePackages(0)).lockDays).to.be.equal(100)
        })
    })
    describe('#stake', () => {
        it("should revert if stake to invalid Stake package", async function () {
            await staking.removeStakePackage(0);
            await expect(staking.stake(ethers.utils.parseUnits("1000", "ether"), 0)).to.be.revertedWith('Invalid package')
        })
        it("should revert if not approve", async function () {
            await expect(staking.connect(receiver1).stake(ethers.utils.parseUnits("1000", "ether"), 0)).to.be.revertedWith('Insufficient balance')
        })
        it("should stake correctly", async function () {
            token.transfer(receiver1.address, ethers.utils.parseUnits("1000", "ether"))
            await token.connect(receiver1).approve(stakingAdress, ethers.utils.parseUnits("1000", "ether"))
            let stakeTx = await staking.connect(receiver1).stake(ethers.utils.parseUnits("1000", "ether"), 0)
            let stakeInfo = await staking.stakes(receiver1.address, 0)
            expect (stakeInfo.amount).to.be.equal(ethers.utils.parseUnits("1000", "ether"))
            expect (stakeInfo.totalProfit).to.be.equal(0)
            await expect(stakeTx).to.emit(staking, 'StakeUpdate')
                .withArgs(receiver1.address, 0, stakeInfo.timePoint, ethers.utils.parseUnits("1000", "ether"), ethers.utils.parseUnits("0", "ether"));
            await expect(await token.balanceOf(receiver1.address)).to.be.equal(0)
        })
    })
    describe('#unStake', () => {
        beforeEach(async () => {
            token.transfer(receiver1.address, ethers.utils.parseUnits("1000", "ether"))
            await token.connect(receiver1).approve(stakingAdress, ethers.utils.parseUnits("1000", "ether"))
            let stakeTx = await staking.connect(receiver1).stake(ethers.utils.parseUnits("1000", "ether"), 0)
            let stakeInfo = await staking.stakes(receiver1.address, 0)
            await expect(await token.balanceOf(receiver1.address)).to.be.equal(0)
        })
        it("should revert if not reach locktime", async function () {
            await expect(staking.connect(receiver1).unStake(0)).to.be.revertedWith('not reach lock time')
        })
        it("should unstake correctly 1", async function () {
            
            await network.provider.send("evm_increaseTime", [86400 * 5 + 100])
            await token.approve(stakingAdress, ethers.utils.parseUnits("1000", "ether"))
           // let stakeTx = await staking.stake(ethers.utils.parseUnits("1000", "ether"), 0)
            expect(await staking.connect(receiver1).calculateMyProfit(0)).to.be.equal(ethers.utils.parseUnits("6.85", "ether"))
            let unStakeTx = await staking.connect(receiver1).unStake(0)
            let stakeInfoAfterRelease = await staking.stakes(receiver1.address, 0)
            const blockNum = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNum);
            await expect(unStakeTx).to.emit(staking, 'StakeReleased')
                .withArgs(receiver1.address, 0, block.timestamp, ethers.utils.parseUnits("1000", "ether"), ethers.utils.parseUnits("6.85", "ether"));
            await expect(await token.balanceOf(receiver1.address)).to.be.equal(ethers.utils.parseUnits("1006.85", "ether"))
            expect(stakeInfoAfterRelease.amount).to.be.equal(0)
            expect(stakeInfoAfterRelease.totalProfit).to.be.equal("0")
            expect(await staking.connect(receiver1).calculateMyProfit(0)).to.be.equal("0")
            expect(await token.balanceOf(reserveAddress)).to.be.equal(ethers.utils.parseUnits("9999993.15", "ether"))

        })
        //1496.5
        it("should unstake correctly 2", async function () {
            token.transfer(receiver1.address, ethers.utils.parseUnits("1000", "ether"))
            await network.provider.send("evm_increaseTime", [86400 * 5 + 100])
            await token.approve(stakingAdress, ethers.utils.parseUnits("1", "ether"))
           // let stakeTx = await staking.stake(ethers.utils.parseUnits("1000", "ether"), 0)
            expect(await staking.connect(receiver1).calculateMyProfit(0)).to.be.equal(ethers.utils.parseUnits("6.85", "ether"))

            await token.connect(receiver1).approve(stakingAdress, ethers.utils.parseUnits("500", "ether"))
            await staking.connect(receiver1).stake(ethers.utils.parseUnits("500", "ether"), 0)
            let stakeInfo = await staking.stakes(receiver1.address, 0)
            expect(stakeInfo.amount).to.be.equal(ethers.utils.parseUnits("1500", "ether"))
            expect(stakeInfo.totalProfit).to.be.equal(ethers.utils.parseUnits("6.85", "ether"))
            await network.provider.send("evm_increaseTime", [86400 * 365])
            await token.approve(stakingAdress, ethers.utils.parseUnits("1", "ether"))
            expect(await staking.connect(receiver1).calculateMyProfit(0)).to.be.equal(ethers.utils.parseUnits("756.925", "ether"))





            
            let unStakeTx2 = await staking.connect(receiver1).unStake(0)
            const blockNum = await ethers.provider.getBlockNumber();
            const block = await ethers.provider.getBlock(blockNum);
            stakeInfo = await staking.stakes(receiver1.address, 0)
            await expect(unStakeTx2).to.emit(staking, 'StakeReleased')
                .withArgs(receiver1.address, 0, block.timestamp, ethers.utils.parseUnits("1500", "ether"), ethers.utils.parseUnits("756.925", "ether"));
            console.log(stakeInfo.timePoint);
            expect(stakeInfo.amount).to.be.equal(0)
            expect(stakeInfo.totalProfit).to.be.equal(ethers.utils.parseUnits("0", "ether"))
            await expect(await token.balanceOf(receiver1.address)).to.be.equal(ethers.utils.parseUnits("2756.925", "ether"))
            await expect(await token.balanceOf(reserveAddress)).to.be.equal(ethers.utils.parseUnits("9999243.075", "ether"))
            //let takeRewardTx = await staking.connect(receiver1).takeProfit(0);
            stakeInfo = await staking.stakes(receiver1.address, 0)

        })
    })
})