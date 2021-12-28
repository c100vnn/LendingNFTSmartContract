import { HardhatUserConfig } from 'hardhat/config'
import 'tsconfig-paths/register'
import '@typechain/hardhat'
import '@nomiclabs/hardhat-ethers'
import '@nomiclabs/hardhat-waffle'
import "@nomiclabs/hardhat-etherscan";
import dotenv from 'dotenv'

dotenv.config()

const config: HardhatUserConfig = {
  defaultNetwork: 'hardhat',
  networks: {
    hardhat: {
      chainId: 1337
    },
    localhost: {
      url: 'http://127.0.0.1:8545'
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/123abc123abc123abc123abc123abcde`,
      accounts: ["e888345be48217c9b2f6c1fb253f36b2944060281a0dda1b7d47369db3ae128c"]
    },
    mainnet: {
      url: "https://bsc-dataseed.binance.org/",
      chainId: 56,
      gasPrice: 20000000000,
     // accounts: ["fcd59a4b02702b7f608b49a436ebb2f743fdaad8d9b3255bd1a3423422a5eed9"]

    },
    testnet: {
      url: "https://data-seed-prebsc-1-s1.binance.org:8545",
      chainId: 97,
      gasPrice: 20000000000,
      accounts: ["b99cb646729956f9088a816a9dd09c0fc5ea11acf883228de11fc95fa2ac7d14"]
    },
   
 
  },
  etherscan: {
    // Your API key for Etherscan
    // Obtain one at https://etherscan.io/
    apiKey: "IZX9DWVHGC9CEQ2SJHP4AWHX4K2U52WGKH"
  },
  solidity: {
    compilers: [
      {
        version: '0.8.4',
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ]
  },
  typechain: {
    outDir: 'types',
    target: 'ethers-v5',
    alwaysGenerateOverloads: true // should overloads with full signatures like deposit(uint256) be generated always, even if there are no overloads?
    // externalArtifacts: ['externalArtifacts/*.json'], // optional array of glob patterns with external artifacts to process (for example external libs from node_modules)
  },
  paths: {
    root: './',
    cache: './cache',
    artifacts: './artifacts',
  },
  mocha: {
    timeout: 200000
  }
}

export default config
