import {buildModule} from '@nomicfoundation/hardhat-ignition/modules';

const TOKEN_ADDRESS = '0x10C274E66c5d92693b82DEf84B8617F7FE838460';

const ThirtyOneGameModule = buildModule('ThirtyOneGameModule', (m) => {
  const tokenAddress = m.getParameter('_token', TOKEN_ADDRESS);
  const initialWinnerPercentage = m.getParameter('_initialWinnerPercentage', 80);

  const game = m.contract('ThirtyOneGame', [
    tokenAddress,
    initialWinnerPercentage,
  ]);

  return {game};
});

export default ThirtyOneGameModule;
