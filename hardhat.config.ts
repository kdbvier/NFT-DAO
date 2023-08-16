import "hardhat-deploy";
import "@nomiclabs/hardhat-ethers";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "dotenv/config";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "ethereum-waffle";
import "@nomicfoundation/hardhat-toolbox";

import { HardhatUserConfig } from "hardhat/types";

// const POLYGON_PRIVATE_KEY_MUMBAI = process.env.POLYGON_PRIVATE_KEY_MUMBAI;
// const POLYGON_MUMBAI_GATEWAY_URL = process.env.POLYGON_MUMBAI_GATEWAY_URL;

// const ETHEREUM_PRIVATE_KEY_RINKEBY = process.env.ETHEREUM_PRIVATE_KEY_RINKEBY;
// const RINKEBY_GATEWAY_URL = process.env.RINKEBY_GATEWAY_URL;
// const GOERLI_GATEWAY_URL = process.env.GOERLI_GATEWAY_URL;
// const POLYGON_GATEWAY_URL = process.env.POLYGON_GATEWAY_URL;
// const BINANCE_GATEWAY_URL = process.env.BSC_MAINNET_GATEWAY_URL;

// const DEPLOYER = process.env.CONTRACT_DEPLOYER;

const GOERLI_RPC_URL = process.env.GOERLI_RPC_URL || "";
const POLYGON_RPC_URL = process.env.POLYGON_RPC_URL || "";
const BINANCE_RPC_URL = process.env.BINANCE_RPC_URL || "";

const PRIVATE_KEY = process.env.PRIVATE_KEY || "";

const TEST_ACCOUNT_A = process.env.PRIVATE_KEY_1 || "";
const TEST_ACCOUNT_B = process.env.PRIVATE_KEY_2 || "";
const TEST_ACCOUNT_C = process.env.PRIVATE_KEY_3 || "";

const ETHERSCAN_API_KEY = process.env.ETHERSCAN_API_KEY || "";
const COINMARKETCAP_API_KEY = process.env.COINMARKETCAP_API_KEY || "";

const config: HardhatUserConfig = {
  defaultNetwork: "hardhat",
  networks: {
    hardhat: {
      chainId: 31337,
      allowUnlimitedContractSize: true,
    },
    localhost: { chainId: 31337, allowUnlimitedContractSize: true },
    goerli: {
      url: GOERLI_RPC_URL,
      accounts: [PRIVATE_KEY, TEST_ACCOUNT_A, TEST_ACCOUNT_B, TEST_ACCOUNT_C],
      chainId: 5,
    },
    mumbai: {
      url: POLYGON_RPC_URL,
      accounts: [PRIVATE_KEY, TEST_ACCOUNT_A, TEST_ACCOUNT_B, TEST_ACCOUNT_C],
      chainId: 80001,
    },
    binance: {
      url: BINANCE_RPC_URL,
      accounts: [PRIVATE_KEY, TEST_ACCOUNT_A, TEST_ACCOUNT_B, TEST_ACCOUNT_C],
      chainId: 97,
    },
  },
  solidity: {
    compilers: [
      {
        version: "0.8.11",
        settings: {
          optimizer: {
            enabled: true,
            runs: 200,
          },
        },
      },
    ],
  },
  namedAccounts: {
    deployer: {
      default: 0,
    },
    holder: {
      default: 1,
    },
  },
  etherscan: {
    apiKey: {
      goerli: ETHERSCAN_API_KEY,
      polygonMumbai: process.env.POLYGONSCAN_API_KEY || "",
      bscTestnet: process.env.BSCSCAN_API_KEY || "",
    },
  },
  gasReporter: {
    enabled: true,
    currency: "USD",
    outputFile: "gas-reporter.txt",
    noColors: true,
    coinmarketcap: COINMARKETCAP_API_KEY,
  },
  paths: {
    sources: "./contracts",
    tests: "./test/unit",
    cache: "./cache",
    artifacts: "./artifacts",
  },
  mocha: {
    timeout: 200000,
  },
};

// This will be used for production deployment
// const POLYGON_PRIVATE_KEY_MAINNET = process.env.POLYGON_PRIVATE_KEY_MAINNET;
// const ETHEREUM_PRIVATE_KEY_MAINNET = process.env.ETHEREUM_PRIVATE_KEY_MAINNET;

// Foundation is not required at this point
// require("@nomicfoundation/hardhat-toolbox");

/** @type import('hardhat/config').HardhatUserConfig */
// module.exports = {
//   networks: {
//     mumbai: {
//       url: POLYGON_MUMBAI_GATEWAY_URL,
//       accounts: [DEPLOYER],
//       etherscan: { apiKey: process.env.API_KEY_POLYGONSCAN },
//     },
//     rinkeby: {
//       url: RINKEBY_GATEWAY_URL,
//       accounts: [DEPLOYER],
//       etherscan: { apiKey: process.env.API_KEY_ETHERSCAN },
//     },
//     goerli: {
//       url: GOERLI_GATEWAY_URL,
//       accounts: [DEPLOYER],
//       etherscan: { apiKey: process.env.API_KEY_ETHERSCAN },
//       gas: "auto",
//       gasPrice: "auto",
//     },
//     polygon: {
//       url: POLYGON_GATEWAY_URL,
//       accounts: [DEPLOYER],
//       etherscan: { apiKey: process.env.API_KEY_ETHERSCAN },
//     },
//     binance: {
//       url: BINANCE_GATEWAY_URL,
//       accounts: [DEPLOYER],
//       etherscan: { apiKey: process.env.API_KEY_BINANCE },
//     },
//   },
//   namedAccounts: {
//     deployer: 0,
//   },
//   solidity: {
//     version: "0.8.16",
//     settings: {
//       optimizer: {
//         enabled: true,
//         runs: 200,
//       },
//     },
//   },
//   paths: {
//     sources: "./contracts",
//     tests: "./test",
//     cache: "./cache",
//     artifacts: "./artifacts",
//   },
//   mocha: {
//     timeout: 20000,
//   },
//   etherscan: {
//     apiKey: {
//       rinkeby: process.env.API_KEY_ETHERSCAN,
//       goerli: process.env.API_KEY_ETHERSCAN,
//       polygonMumbai: process.env.API_KEY_POLYGONSCAN,
//       polygon: process.env.API_KEY_POLYGONSCAN,
//       bscTestnet: process.env.API_KEY_BSCSCAN,
//       bsc: process.env.API_KEY_BSCSCAN,
//     },
//   },
//   gasReporter: {
//     currency: "USD",
//     // gasPrice: 21,
//     coinmarketcap: "5effee48-69c2-4532-8e02-68c137e1fe85",
//   },
// };

export default config;
