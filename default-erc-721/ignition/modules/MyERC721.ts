import {buildModule} from '@nomicfoundation/hardhat-ignition/modules';

export default buildModule('MyERC721Module', (m) => {
  const myERC721 = m.contract('MyERC721', ['MomZzangTestNFT', 'MZTN']);

  return {myERC721};
});
