import { BigNumber } from '@ethersproject/bignumber';
import { WithdrawRequestedEvent } from './../../types/RewardPool.d';
import { network } from 'hardhat';
//Có 2 functions:
//requestWithdraw để user tạo request => object được tạo, event được emit. Khó khăn: check event ntn, fast foward thời gian ntn
//distributeReward để admin gọi và gửi tiền cho người request => update object, tính fee chuẩn
import { assert, expect } from 'chai'
import { ethers } from 'hardhat'
import { RewardPool, FarmFinace } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BigNumberish } from "ethers";
import Web3 from 'web3';
const web3 = new Web3('ws://localhost:8546');


describe('Reward pool contract', function () {

    let [admin, receiver1, receiver2]: SignerWithAddress[] = []
    let rewardPool: RewardPool
    let token: FarmFinace
    let rewardPoolAddress: string
    let rewardPoolAmount: string = "99000000000000000000000000" // 99000000*10^18
    beforeEach(async () => {
        [admin, receiver1, receiver2] = await ethers.getSigners()
        const Token = await ethers.getContractFactory('FarmFinace')
        token = await Token.deploy()
        await token.deployed()
        const tokenAddress = token.address

        const ganache = require("ganache-core");
        const web3 = new Web3(ganache.provider());

        const RewardPool = await ethers.getContractFactory('RewardPool')
        rewardPool = await RewardPool.deploy(tokenAddress)
        await rewardPool.deployed()
        rewardPoolAddress = rewardPool.address

        await token.transfer(rewardPoolAddress, rewardPoolAmount )
        console.log("admin balance: ",await token.balanceOf(admin.address))
        console.log("reward pool balance: ",await token.balanceOf(rewardPoolAddress))
    })

    it("#requestWithdraw should revert if duration < 1 day", async function () {
        const rewardAmount = ethers.utils.parseUnits('1000', 'ether')
        
        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(0)
        
        await expect((rewardPool.connect(receiver1).requestWithdraw(rewardAmount)))
        .to
        .be
        .reverted;
    })

    it("#requestWithdraw should revert if amount < min amount ", async function () {
        const rewardAmount = ethers.utils.parseUnits('599', 'ether')

        await expect((rewardPool.connect(receiver1).requestWithdraw(rewardAmount)))
        .to
        .be
        .reverted;
    })

    it("#requestWithdraw should revert if contract was paused ", async function () {
        const rewardAmount = ethers.utils.parseUnits('600', 'ether')

        await rewardPool.pause()

        await expect((rewardPool.connect(receiver1).requestWithdraw(rewardAmount)))
        .to
        .be
        .reverted;

    })

    it("#requestWithdraw should submit correctly", async function () {
      // emit a new event WithdrawRequested
      // a new struct created in withdraws mapping

        const rewardAmount = ethers.utils.parseUnits('600', 'ether')

        await expect(rewardPool.connect(receiver1).requestWithdraw(rewardAmount))
        .to
        .emit(rewardPool, 'WithdrawRequested')
        .withArgs((await rewardPool.withdraws(0)).id, (await rewardPool.withdraws(0)).user, (await rewardPool.withdraws(0)).amount, (await rewardPool.withdraws(0)).timestamp)

    })

    it("#distributeReward should revert if not admin ", async function () {
        const rewardAmount = ethers.utils.parseUnits('600', 'ether')

        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await expect( rewardPool.connect(receiver1).distributeReward(0))
        .to
        .be
        .reverted;
    })

  
    it("#distributeReward should take 2% fee if request day > 5 day", async function () {
        
        const rewardAmount = ethers.utils.parseUnits('1000', 'ether')

        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(0)

        var latestBalance : BigNumber = await token.balanceOf(receiver1.address)

        await network.provider.send("evm_increaseTime", [432001])
        
        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(1)

        var newestBalance : BigNumber = await token.balanceOf(receiver1.address)
        
        await expect(newestBalance.sub(latestBalance)) 
        .to
        .be
        .equal('980000000000000000000');
    })


    it("#distributeReward should take 12% fee if request day between 4 and 5 day", async function () {
        
        const rewardAmount = ethers.utils.parseUnits('1000', 'ether')

        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(0)

        var latestBalance : BigNumber = await token.balanceOf(receiver1.address)

        await network.provider.send("evm_increaseTime", [345601])
        
        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(1)

        var newestBalance : BigNumber = await token.balanceOf(receiver1.address)
        
        await expect(newestBalance.sub(latestBalance)) 
        .to
        .be
        .equal('880000000000000000000');
    })
    it("#distributeReward should take 22% fee if request day between 3 and 4 day", async function () {
        
        const rewardAmount = ethers.utils.parseUnits('1000', 'ether')

        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(0)

        var latestBalance : BigNumber = await token.balanceOf(receiver1.address)

        await network.provider.send("evm_increaseTime", [259201])
        
        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(1)

        var newestBalance : BigNumber = await token.balanceOf(receiver1.address)
        
        await expect(newestBalance.sub(latestBalance)) 
        .to
        .be
        .equal('780000000000000000000');
    })
    it("#distributeReward should take 32% fee if request day between 2 and 3 day", async function () {
        
        const rewardAmount = ethers.utils.parseUnits('1000', 'ether')

        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(0)

        var latestBalance : BigNumber = await token.balanceOf(receiver1.address)

        await network.provider.send("evm_increaseTime", [172801])
        
        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(1)

        var newestBalance : BigNumber = await token.balanceOf(receiver1.address)
        
        await expect(newestBalance.sub(latestBalance)) 
        .to
        .be
        .equal('680000000000000000000');
    })
    it("#distributeReward should take 42% fee if request day between 1 and 2 day", async function () {
        
        const rewardAmount = ethers.utils.parseUnits('1000', 'ether')

        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(0)

        var latestBalance : BigNumber = await token.balanceOf(receiver1.address)

        await network.provider.send("evm_increaseTime", [86401])
        
        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(1)

        var newestBalance : BigNumber = await token.balanceOf(receiver1.address)
        
        await expect(newestBalance.sub(latestBalance)) 
        .to
        .be
        .equal('580000000000000000000');
    })
   
    it("#distributeReward 5 days in a row", async function () {
        
        const rewardAmount = ethers.utils.parseUnits('1000', 'ether')

        var latestBalance : BigNumber = await token.balanceOf(receiver1.address)

        console.log(latestBalance);

        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(0)

        await network.provider.send("evm_increaseTime", [86401])
        
        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(1)

        await network.provider.send("evm_increaseTime", [86401])
        
        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(2)

        await network.provider.send("evm_increaseTime", [86401])
        
        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(3)

        await network.provider.send("evm_increaseTime", [86401])
        
        await rewardPool.connect(receiver1).requestWithdraw(rewardAmount)
        
        await rewardPool.distributeReward(4)

        var newestBalance : BigNumber = await token.balanceOf(receiver1.address)

        await expect(newestBalance.sub(latestBalance))
        .to
        .be
        .equal('3300000000000000000000')
    })
})