import { ethers, network } from 'hardhat'
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs'
import { resolve } from 'path'

import { Contracts } from 'tasks/interface/contract-info.interface'

async function main() {
  const DEPLOYMENT_PATH = resolve('deployments')
  const DATA_PATH = resolve(DEPLOYMENT_PATH, 'data')
  const CONTRACT_PATH = resolve(DATA_PATH, `contracts.${network.name}.json`)

  if (!existsSync(DATA_PATH)) {
    mkdirSync(DATA_PATH)
  }

  let contractList: Contracts = existsSync(CONTRACT_PATH) ? JSON.parse(readFileSync(CONTRACT_PATH).toString()) : {}


  const NFTMarket = await ethers.getContractFactory('NFTMarket')
  const nftMarket = await NFTMarket.deploy()
  await nftMarket.deployed()
  console.log('nftMarket deployed to:', nftMarket.address)

  const NFT = await ethers.getContractFactory('NFT')
  const nft = await NFT.deploy(nftMarket.address)
  await nft.deployed()
  console.log('nft deployed to:', nft.address)

  contractList = {
    nft: {
      name: 'NFT',
      address: nft.address
    },
    ntfMarket: {
      name: 'NFTMarket',
      address: nftMarket.address
    }
  }

  writeFileSync(CONTRACT_PATH, JSON.stringify(contractList, null, 2))
  console.log(`Wrote data to file ${CONTRACT_PATH}`)
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
