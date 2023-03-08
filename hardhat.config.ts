import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";
import '@openzeppelin/hardhat-upgrades';
import "@nomiclabs/hardhat-etherscan";

require("dotenv").config();


let deploy = process.env.Deploy || "4149e3ed85d04f91783a1494e961aaee0ee1ace5890106965c68ba30e45d9210";
let myKey = process.env.ApiKey || "toto";

const config: HardhatUserConfig = {
  solidity: {
    version: "0.8.18",
    settings: {
      optimizer: {
        enabled: true,
        runs: 1000,
      },
    },
  },
  networks: {
    hardhat: {
      accounts: [
        {
          balance: "100000000000000000000",
          // 0x038AfE1F8393b852817129709ffEa6211B12ab8d
          privateKey: "4149e3ed85d04f91783a1494e961aaee0ee1ace5890106965c68ba30e45d9210",
        },
        {
          balance: "300000000000000000000",
          // 0x2E5CA01422E48076150B0e7f126ab48E97Ee09Ac
          privateKey:
            "5166483b80cba5a1b5833f6cd2765d71c9820085d7437bed99ae288b975fba52",
        },
        {
          balance: "60000000000000000000",
          // 0x0E58268df8580334B15090b9D0a7e73e5185B99b
          privateKey:
            "e7cb0d971d967d04ac647fa7c5f1adfc2dcb126737b70ddfc4bbee03f9740ed1",
        },
        {
          balance: "20000000000000000000",
          // 0x4C725CB27700E09383d79346D71b3D6efd1c9444
          privateKey:
            "6c54bbcc10f0fdbff9b150be32a2381cb46af0f4d50b0858c01c850945008d57",
        },
      ],
    },
    fantomtest: {
      url: "https://rpc.ankr.com/fantom_testnet",
      accounts: [deploy],
      chainId: 4002,
      live: false,
      saveDeployments: true,
      gasMultiplier: 2,
    }
  },
  etherscan: {
    apiKey: {
      ftmTestnet: myKey,
    },
  }

};

export default config;
