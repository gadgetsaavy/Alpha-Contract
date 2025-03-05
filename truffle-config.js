module.exports = {
  // Network configuration
  networks: {
    // Development network configuration (used for local development)
    development: {
      host: "127.0.0.1", // Localhost
      port: 8545, // Port number
      network_id: "*", // Match any network id
    },
    // Config for connecting to Rinkeby test network via Infura
    rinkeby: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://rinkeby.infura.io/v3/${process.env.INFURA_PROJECT_ID}`),
      network_id: 4, // Rinkeby's network id
      gas: 5500000, // Gas limit
      gasPrice: 10000000000, // Gas price
    },
    // Mainnet network configuration
    mainnet: {
      provider: () => new HDWalletProvider(process.env.MNEMONIC, `https://mainnet.infura.io/v3/${process.env.INFURA_PROJECT_ID}`),
      network_id: 1, // Mainnet's network id
      gas: 5500000, // Gas limit
      gasPrice: 20000000000, // Gas price (in wei)
    },
  },

  // Compiler settings
  compilers: {
    solc: {
      version: "0.8.0", // Solidity version
      settings: {
        optimizer: {
          enabled: true, // Enable optimization
          runs: 200, // Number of optimization runs
        },
      },
    },
  },

  // Configuration for migrations
  migrations_directory: "./migrations",
  contracts_directory: "./contracts",

  // Plugins (e.g., for verifying contracts)
  plugins: ["truffle-plugin-verify"],

  // Enable debugging
  mocha: {
    timeout: 100000, // Set the test timeout to 100 seconds
  },
};
