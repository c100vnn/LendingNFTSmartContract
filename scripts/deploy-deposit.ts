import { ethers, network } from 'hardhat'
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs'
import { resolve } from 'path'

import { Contracts } from 'tasks/interface/contract-info.interface'

async function main() {
  try {
    const DEPLOYMENT_PATH = resolve('deployments')
  const FFTADDRESS = ''
  const REWARD_ADDRESS = ''
  const DATA_PATH = resolve(DEPLOYMENT_PATH, 'data')
  const CONTRACT_PATH = resolve(DATA_PATH, `contracts.${network.name}.json`)

  if (!existsSync(DATA_PATH)) {
    mkdirSync(DATA_PATH)
  }

  let contractList: Contracts = existsSync(CONTRACT_PATH) ? JSON.parse(readFileSync(CONTRACT_PATH).toString()) : {}

  const token = await ethers.getContractAt("FarmFinance", FFTADDRESS);
  //const token = await ethers.getContractAt("FarmFinance", FFTADDRESS);
  
  const Deposit = await ethers.getContractFactory('Deposit')
  const deposit = await Deposit.deploy(FFTADDRESS, REWARD_ADDRESS )
  await deposit.deployed()
  console.log('Deposit deployed to:', deposit.address)

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
