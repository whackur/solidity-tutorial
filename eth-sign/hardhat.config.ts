import type {HardhatUserConfig} from 'hardhat/config';
import hardhatToolboxViem from '@nomicfoundation/hardhat-toolbox-viem';
import 'dotenv/config';
import * as dotenv from 'dotenv';
import path from 'path';
import {fileURLToPath} from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

dotenv.config({path: path.resolve(__dirname, '../.env')});

const config: HardhatUserConfig = {
  plugins: [hardhatToolboxViem],
  solidity: {
    version: '0.8.30',
    settings: {
      optimizer: {
        enabled: true,
        runs: 200,
      },
    },
  },
  networks: {
    sepolia: {
      type: 'http',
      url: process.env.SEPOLIA_RPC_URL || '',
      accounts: {
        mnemonic: process.env.DEPLOYER_MNEMONIC || '',
      },
    },
  },
  verify: {
    etherscan: {
      apiKey: process.env.SEPOLIA_API_KEY || '',
    },
  },
};

export default config;
