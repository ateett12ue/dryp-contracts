import * as dotenv from "dotenv";

import { HardhatUserConfig, task } from "hardhat/config";
import "@nomiclabs/hardhat-etherscan";
import "@typechain/hardhat";
import "hardhat-gas-reporter";
import "solidity-coverage";
import "solidity-docgen";
import "hardhat-deploy";
import "@nomiclabs/hardhat-waffle";
import "@nomiclabs/hardhat-ethers";
import "hardhat-dependency-compiler";
// import "@matterlabs/hardhat-zksync-solc";
// import "@matterlabs/hardhat-zksync-deploy";
// import "@matterlabs/hardhat-zksync-verify";
// import "@matterlabs/hardhat-zksync-upgradable";

import "./tasks";

dotenv.config();

// This is a sample Hardhat task. To learn how to create your own go to
// https://hardhat.org/guides/create-task.html
task("accounts", "Prints the list of accounts", async (taskArgs, hre) => {
  const accounts = await hre.ethers.getSigners();

  for (const account of accounts) {
    console.log(account.address);
  }
});

// You need to export an object to set up your config
// Go to https://hardhat.org/config/ to learn more

const config: HardhatUserConfig = {
  paths: {
    artifacts: "artifacts",
    cache: "cache",
    deploy: "src/deploy",
    sources: "contracts",
  },
  mocha: {
    timeout: 1000000,
  },
  namedAccounts: {
    deployer: 0,
    verifiedSigner: 5,
  },
  solidity: {
    compilers: [
      {
        version: "0.8.2",
        settings: {
          optimizer: { enabled: true, runs: 1000000 },
          viaIR: true,
        },
      },
    ],
  },
  networks: {
    hardhat: {
      accounts: {
        accountsBalance: "10000000000000000000000000",
      },
      allowUnlimitedContractSize: true,
      chainId: 31337,
      zksync: true,
    },
    mainnet: {
      url: process.env.ETH_MAINNET_URL || "",
      chainId: 1,
      accounts:
        process.env.PRIVATE_KEY !== undefined
          ? [process.env.PRIVATE_KEY]
          : [""],
    },
    goerli: {
      url: process.env.GOERLI_URL || "",
      chainId: 5,
      accounts:
        process.env.PRIVATE_KEY !== undefined
          ? [process.env.PRIVATE_KEY]
          : [""],
    },
    sepolia: {
      url: process.env.SEPOLIA_URL || "",
      accounts:
        process.env.PRIVATE_KEY !== undefined
          ? [process.env.PRIVATE_KEY]
          : [""],
      chainId: 11155111,
    },
  },

  gasReporter: {
    outputFile: "gas-report.txt",
    enabled: process.env.REPORT_GAS !== undefined,
    currency: "USD",
    noColors: true,
    coinmarketcap: process.env.COIN_MARKETCAP_API_KEY || "",
    token: "ETH",
  },

  etherscan: {
    apiKey: {
      mainnet: process.env.ETHERSCAN_API_KEY || "",
      sepolia: process.env.ETHERSCAN_API_KEY || "",
      goerli: process.env.ETHERSCAN_API_KEY || "",
    },
    customChains: [],
  },
};

export default config;
