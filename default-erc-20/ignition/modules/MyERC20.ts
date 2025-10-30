import {buildModule} from '@nomicfoundation/hardhat-ignition/modules';
import {parseEther} from 'viem';

export default buildModule('MyERC20Module', (m) => {
  const myERC20 = m.contract('MyERC20', [
    'MyERC20',
    'MERC20',
    parseEther('100000000'),
  ]);

  return {myERC20};
});
