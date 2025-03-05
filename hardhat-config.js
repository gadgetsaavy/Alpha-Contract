require("@nomiclabs/hardhat-waffle"); // Hardhat plugin for working with Waffle (used for testing)
require("@nomiclabs/hardhat-ethers"); // Hardhat plugin for working with Ethers.js
require("dotenv").config(); // For loading environment variables from .env file

module.exports = {
  solidity: {
    version: "0.8.0", // Solidity version
    settings: {
      optimizer: {
        enabled: true, // Enable optimization
        runs: 200, // Number of optimization runs
      },
    },
  },

  // Network configuration
  networks: {
    hardhat: {
      chainId: 1337, // Default Hardhat network
    },
    rinkeby: {
      url: `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // Rinkeby network URL from Infura
      accounts: [`0x${process.env.PRIVATE_KEY}`], // Use your wallet's private key
    },
    mainnet: {
      url: `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`, // Mainnet network URL from Infura
      accounts: [`0x${process.env.PRIVATE_KEY}`], // Use your wallet's private key
    },
  },

  // Solidity settings
  etherscan: {
    apiKey: process.env.ETHERSCAN_API_KEY, // API key for verifying contracts on Etherscan
  },

  // Configuration for gas limits and gas price
  gas: {
    gasPrice: 20000000000, // Gas price for transactions (in wei)
    gasLimit: 8000000, // Gas limit for transactions
  },
};
