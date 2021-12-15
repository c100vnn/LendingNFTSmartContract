import { assert, expect } from 'chai'
import { ethers } from 'hardhat'
import { Airdrop, FarmFinace } from 'types'
import { SignerWithAddress } from '@nomiclabs/hardhat-ethers/signers'
import { BigNumberish } from "ethers";

describe('Airdrop contract', function () {
    type PaymentInfo = {
        payee: string;
        amount: BigNumberish;
    }
    let accounts: SignerWithAddress[] = []
    let airdrop: Airdrop
    let token: FarmFinace
    let airdropAddress: string
    beforeEach(async () => {
        accounts = await ethers.getSigners()
        const Token = await ethers.getContractFactory('FarmFinace')
        token = await Token.deploy()
        await token.deployed()
        const tokenAddress = token.address

        const Airdrop = await ethers.getContractFactory('Airdrop')
        airdrop = await Airdrop.deploy(tokenAddress)
        await airdrop.deployed()
        airdropAddress = airdrop.address
        // accounts.forEach(account => {
        //     console.log(account.address);

        // });
    })
    it("#batchPayout should transfer successfully", async function () {
        token.connect(accounts[1]).transfer
        token.connect(accounts[1]).transfer
        token.transfer(airdropAddress,200)
        let balance = await token.balanceOf(airdropAddress)
        console.log("balance before: ", balance)
        let payments: PaymentInfo[] = [
            {
                payee: accounts[1].address,
                amount: 100
            },
            {
                payee: accounts[2].address,
                amount: 100
            },
        ]
        let payTx = await airdrop.batchPayout(payments)
        console.log(payTx);
        balance = await token.balanceOf(airdropAddress)
        await expect(balance).to.be.equal(0)
        await expect(await token.balanceOf(accounts[1].address)).to.be.equal(100)
        await expect( await token.balanceOf(accounts[2].address)).to.be.equal(100)
    })
    
})