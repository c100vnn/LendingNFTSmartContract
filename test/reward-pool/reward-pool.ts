import { network } from 'hardhat';
import { assert, expect } from 'chai'
import { ethers } from 'hardhat'
import { RewardPool, FarmFinace } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
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
         await rewardPool.requestWithdraw(rewardAmount)
        //console.log(requestTx)
        // await network.provider.send("evm_increaseTime", [86000])
        // await expect((await rewardPool.requestWithdraw(rewardAmount)))
        // .to
        // .be
        // .reverted;
    })
    it("#requestWithdraw should revert if amount < min amount ", async function () {
      
    })
    it("#requestWithdraw should revert if contract was paused ", async function () {
      
    })
    it("#requestWithdraw should submit correctly", async function () {
      // emit a new event WithdrawRequested
      // a new struct created in withdraws mapping
    })
    it("#distributeReward should revert if not admin ", async function () {
      
    })
    it("#distributeReward should revert if time duration < 1 day ", async function () {
      
    })
    it("#distributeReward should revert if amount < min amount ", async function () {
      
    })
    it("#distributeReward should take 2% fee if request day > 5 day", async function () {
        //emit a new event RewardDistributed
        //struct updated in withdraws mapping
    })
    it("#distributeReward should take 12% fee if request day between 4 and 5 day", async function () {
      
    })
    it("#distributeReward should take 22% fee if request day between 3 and 4 day", async function () {
      
    })
    it("#distributeReward should take 32% fee if request day between 2 and 3 day", async function () {
      
    })
    it("#distributeReward should take 42% fee if request day between 1 and 2 day", async function () {
      
    })
   
    it("#distributeReward  ", async function () {
      
    })
})