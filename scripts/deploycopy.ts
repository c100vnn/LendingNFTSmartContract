import { ethers, network } from 'hardhat'
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs'
import { resolve } from 'path'

import { Contracts } from 'tasks/interface/contract-info.interface'

async function main() {
  const NFT = await ethers.getContractFactory('FarmFinanceNFT')
  const nft = await NFT.deploy('0x8e7cbC6C11b1e906dbcA2BfEe2699CDc2ab93624')
  await nft.deployed()
  console.log('farmFinance deployed to:', nft.address)
}
// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
main()
  .then(() => process.exit(0))
  .catch((error) => {
    console.error(error)
    process.exit(1)
  })
