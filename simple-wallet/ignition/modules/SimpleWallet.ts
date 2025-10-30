import {buildModule} from '@nomicfoundation/hardhat-ignition/modules';

const SimpleWalletModule = buildModule('SimpleWalletModule', (m) => {
  const simpleWallet = m.contract('SimpleWallet');

  return {simpleWallet};
});

export default SimpleWalletModule;
