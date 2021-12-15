import { ethers, network } from 'hardhat'
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs'
import { resolve } from 'path'

import { Contracts } from 'tasks/interface/contract-info.interface'

async function main() {
  try {
    const DEPLOYMENT_PATH = resolve('deployments')
  const DATA_PATH = resolve(DEPLOYMENT_PATH, 'data')
  const CONTRACT_PATH = resolve(DATA_PATH, `contracts.${network.name}.json`)
  const airdropAddress = "0x3c44cdddb6a900fa2b585dd299e03d12fa4293bc";
  const privateSale = "0x90f79bf6eb2c4f870365e785982e1f101e93b906";
  const preSale = "0x15d34aaf54267db7d7c367839aaf71a00a2c6a65";
  const marketting = "0x9965507d1a55bcc2695c58ba16fb37d819b0a4dc";
  const liquidity = "0x976ea74026e726554db657fa54763abd0c3a0aa9";
  const team = "0x14dc79964da2c08b23698b3d3cc7ca32193d9955";
  const partner = "0x23618e81e3f5cdf7f54c3d65f7fbc0abf5b21e8f";
  if (!existsSync(DATA_PATH)) {
    mkdirSync(DATA_PATH)
  }

  let contractList: Contracts = existsSync(CONTRACT_PATH) ? JSON.parse(readFileSync(CONTRACT_PATH).toString()) : {}

  const Token = await ethers.getContractFactory('FarmFinance')
  const token = await Token.deploy()
  await token.deployed()
  console.log('farmFinance deployed to:', token.address)

//   const Staking = await ethers.getContractFactory('Staking')
//   const staking = await Staking.deploy(token.address)
//   await staking.deployed()
//   console.log('staking contract deployed to:', staking.address)
//   //reserve for staing
//   const Reserve = await ethers.getContractFactory('Reserve')
//   const reserve = await Reserve.deploy(token.address, staking.address)
//   await reserve.deployed()
//   console.log('reserve deployed to:', reserve.address)
//   await staking.setReserve(reserve.address)

//   const RewardPool = await ethers.getContractFactory('RewardPool')
//   const rewardPool = await RewardPool.deploy(token.address)
//   await rewardPool.deployed()
//   console.log('RewardPool deployed to:', rewardPool.address)

  //await token.transfer(reserve.address, ethers.utils.parseUnits("20000000", "ether"))
 // await token.transfer(rewardPool.address, ethers.utils.parseUnits("99000000", "ether"))
  await token.transfer(airdropAddress, ethers.utils.parseUnits("2000000", "ether"))
  await token.transfer(privateSale, ethers.utils.parseUnits("10000000", "ether"))
  await token.transfer(preSale, ethers.utils.parseUnits("20000000", "ether"))
  await token.transfer(marketting, ethers.utils.parseUnits("14000000", "ether"))
  await token.transfer(liquidity, ethers.utils.parseUnits("5000000", "ether"))
  await token.transfer(team, ethers.utils.parseUnits("10000000", "ether"))
  await token.transfer(partner, ethers.utils.parseUnits("20000000", "ether"))
  

  contractList = {
    token: {
      name: 'Token',
      address: token.address
    },
    // reserve: {
    //   name: 'Reserve',
    //   address: reserve.address
    // },
    // staking: {
    //   name: 'Staking',
    //   address: staking.address
    // },
    // rewardPool: {
    //   name: 'RewardPool',
    //   address: rewardPool.address
    // },
  }

  writeFileSync(CONTRACT_PATH, JSON.stringify(contractList, null, 2))
  console.log(`Wrote data to file ${CONTRACT_PATH}`)
  } catch (error) {
    console.log(error);
    
  }
  
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
