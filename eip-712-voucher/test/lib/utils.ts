import {network} from 'hardhat';
import type {WalletClient} from 'viem';

export async function createSignature(
  signer: WalletClient,
  redeemerAddress: `0x${string}` | undefined,
  voucherId: bigint,
  amount: bigint,
  voucherContractAddress: `0x${string}` | undefined,
) {
  if (!signer.account) {
    throw new Error('Signer account is not available');
  }
  if (!redeemerAddress || !voucherContractAddress) {
    throw new Error('Invalid address provided');
  }
  const {viem} = await network.connect();
  const publicClient = await viem.getPublicClient();
  const chainId = await publicClient.getChainId();

  const domain = {
    name: 'MyEIP712App',
    version: '1',
    chainId: chainId,
    verifyingContract: voucherContractAddress,
  };

  const types = {
    Voucher: [
      {name: 'redeemer', type: 'address'},
      {name: 'voucherId', type: 'uint256'},
      {name: 'amount', type: 'uint256'},
    ],
  };

  const value = {
    redeemer: redeemerAddress,
    voucherId,
    amount,
  };

  return await signer.signTypedData({
    account: signer.account,
    domain,
    types,
    primaryType: 'Voucher',
    message: value,
  });
}
