import { HardhatUserConfig } from "hardhat/config";

import "@nomicfoundation/hardhat-toolbox";
import "./tasks/taks";
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
        "0x9a9c92b1a01fda896e0be2da17cdd41fccc9817d0aec0f12a08c088865702393",
        "0x5c554fca05636ebecf7081c575ba455b52ed41171f488d2818ca36d9a77825cd",
      ],
    },
  },
};

export default config;
