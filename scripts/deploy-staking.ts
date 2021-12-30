import { ethers, network } from 'hardhat'
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs'
import { resolve } from 'path'

import { Contracts } from 'tasks/interface/contract-info.interface'

async function main() {
  try {
    const DEPLOYMENT_PATH = resolve('deployments')
  const FFTADDRESS = '0x4bcD459D6Cae6774e8e0f6DF75fc2757D4FD57a6'

  const Staking = await ethers.getContractFactory('Staking')
  const staking = await Staking.deploy(FFTADDRESS)
  await staking.deployed()
  console.log('staking contract deployed to:', staking.address)
  //reserve for staing
  const Reserve = await ethers.getContractFactory('Reserve')
  const reserve = await Reserve.deploy(FFTADDRESS, staking.address)
  await reserve.deployed()
  console.log('reserve deployed to:', reserve.address)
  await staking.setReserve(reserve.address)

  const RewardPool = await ethers.getContractFactory('RewardPool')
  const rewardPool = await RewardPool.deploy(FFTADDRESS)
  await rewardPool.deployed()
  console.log('RewardPool deployed to:', rewardPool.address)

  // contractList = {
  //   token: {
  //     name: 'Token',
  //     address: token.address
  //   },
  //   reserve: {
  //     name: 'Reserve',
  //     address: reserve.address
  //   },
  //   staking: {
  //     name: 'Staking',
  //     address: staking.address
  //   },
  //   rewardPool: {
  //     name: 'RewardPool',
  //     address: rewardPool.address
  //   },
  // }
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
