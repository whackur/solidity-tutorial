import {buildModule} from '@nomicfoundation/hardhat-ignition/modules';

export default buildModule('VoucherModule', (m) => {
  const voucher = m.contract('Voucher');

  return {voucher};
});
