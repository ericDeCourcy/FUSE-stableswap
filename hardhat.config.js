/**
 * @type import('hardhat/config').HardhatUserConfig
 */
 
// ethers plugin
require('@nomiclabs/hardhat-ethers');

// hardhat web3 plugin
require("@nomiclabs/hardhat-web3");


// private key link
const {privateKey} = require('./secrets.json');

// etherscan plugin
require("@nomiclabs/hardhat-etherscan");

require("@nomiclabs/hardhat-ethers");

module.exports = {
  solidity: {
    version: "0.6.12",
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  
  networks: {
    hardhat: {
      throwOnTransactionFailures: true,
      throwOnCallFailures: true,
      allowUnlimitedContractSize: true,
    },
    
    fuse: {
      url: `https://rpc.fuse.io/`,
      chainId: 122,
      accounts: [privateKey],
      throwOnTransactionFailures: false,
      throwOnCallFailures: false,
      gas: 10000000
    },

    ropsten: {
      url: "https://eth-ropsten.alchemyapi.io/v2/u2Y8hHpPxYUvAeu4tynnAxE_6mz2V-bw",
      accounts: [privateKey]
    },
  },

  etherscan: {
    apiKey: "XPQCZH3JU2Q8ZGK28GMIIPV5NMTRIXVQZW"
  }
};

