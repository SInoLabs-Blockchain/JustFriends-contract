import { HardhatUserConfig } from "hardhat/config";
import "@nomicfoundation/hardhat-toolbox";

const config: HardhatUserConfig = {
  solidity: {
    compilers: [
      {
        version: "0.8.20",
        settings: {
          optimizer: { enabled: true, runs: 1000000 },
          // viaIR: true,
        },
      },
    ],
  },
  networks: {
    baobab: {
      url: `https://public-en-baobab.klaytn.net`,
      accounts: [
        process.env.YOUR_PRIVATE_KEY ||
          "edd189f5eebebb23d17a392e4bfaf2581fd13a40cc039037c2ec77555bbbfdb1",
      ],
    },
  },
};

export default config;
