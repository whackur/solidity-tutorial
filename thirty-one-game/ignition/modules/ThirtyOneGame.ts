import {buildModule} from '@nomicfoundation/hardhat-ignition/modules';

const TOKEN_ADDRESS = '0x...'; // TODO: 실제 토큰 주소로 변경해주세요.

const ThirtyOneGameModule = buildModule('ThirtyOneGameModule', (m) => {
  const tokenAddress = m.getParameter('_token', TOKEN_ADDRESS);

  const game = m.contract('ThirtyOneGame', [tokenAddress]);

  return {game};
});

export default ThirtyOneGameModule;
