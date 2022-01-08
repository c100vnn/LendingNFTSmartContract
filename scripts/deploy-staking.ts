import { ethers, network } from 'hardhat'
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs'
import { resolve } from 'path'

import { Contracts } from 'tasks/interface/contract-info.interface'

async function main() {
  try {
    const DEPLOYMENT_PATH = resolve('deployments')
  const FFTADDRESS = '0x1ceBfb39B335A7929b4a7F8A6a926DE52cf726F5'
  const DATA_PATH = resolve(DEPLOYMENT_PATH, 'data')
  const CONTRACT_PATH = resolve(DATA_PATH, `contracts.${network.name}.json`)

  if (!existsSync(DATA_PATH)) {
    mkdirSync(DATA_PATH)
  }

  let contractList: Contracts = existsSync(CONTRACT_PATH) ? JSON.parse(readFileSync(CONTRACT_PATH).toString()) : {}

  const token = await ethers.getContractAt("FarmFinance", FFTADDRESS);

  const Staking = await ethers.getContractFactory('Staking')
  const staking = await Staking.deploy(FFTADDRESS)
  await staking.deployed()
  console.log('staking contract deployed to:', staking.address)
  //reserve for staing
  const Reserve = await ethers.getContractFactory('Reserve')
  const reserve = await Reserve.deploy(FFTADDRESS, staking.address)
  await reserve.deployed()
  console.log('reserve deployed to:', reserve.address)
  const setReserveTx = await staking.setReserve(reserve.address)
  await setReserveTx.wait()
  console.log('set reserve completed:')

  const transferTx = await token.transfer(reserve.address, ethers.utils.parseUnits("20000000", "ether"))
  await transferTx.wait()
  let reserveBalance = await token.balanceOf(reserve.address)
  console.log('reserve is holding token:', reserveBalance)

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
