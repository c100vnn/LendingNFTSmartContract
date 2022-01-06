import { ethers, network } from 'hardhat'
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs'
import { resolve } from 'path'

import { Contracts } from 'tasks/interface/contract-info.interface'

async function main() {
  try {
    const DEPLOYMENT_PATH = resolve('deployments')
  const FFTADDRESS = ''
  const DATA_PATH = resolve(DEPLOYMENT_PATH, 'data')
  const CONTRACT_PATH = resolve(DATA_PATH, `contracts.${network.name}.json`)

  if (!existsSync(DATA_PATH)) {
    mkdirSync(DATA_PATH)
  }

  let contractList: Contracts = existsSync(CONTRACT_PATH) ? JSON.parse(readFileSync(CONTRACT_PATH).toString()) : {}

  const token = await ethers.getContractAt("FarmFinance", FFTADDRESS);
  
  const RewardPool = await ethers.getContractFactory('RewardPool')
  const rewardPool = await RewardPool.deploy(FFTADDRESS)
  await rewardPool.deployed()
  console.log('RewardPool deployed to:', rewardPool.address)

  const transferTx = await token.transfer(rewardPool.address, ethers.utils.parseUnits("99000000", "ether"))
  await transferTx.wait()
  let rewardBalance = await token.balanceOf(rewardPool.address)
  console.log('reward pool is holding token:', rewardBalance)

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
