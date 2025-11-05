import {describe, it} from 'node:test';
import assert from 'node:assert/strict';
import {network} from 'hardhat';
import type {GetContractReturnType} from 'viem';
import {createSignature} from './lib/utils.js';
import voucherJSON from '../artifacts/contracts/Voucher.sol/Voucher.json' with {type: 'json'};
const voucherABI = voucherJSON.abi;

describe('Voucher', function () {
  type VoucherContract = GetContractReturnType<typeof voucherABI>;

  async function deployVoucherFixture() {
    const {viem} = await network.connect();
    const [signer, redeemer, otherAccount] = await viem.getWalletClients();

    const voucherContract = await viem.deployContract('Voucher');
    const publicClient = await viem.getPublicClient();

    return {
      viem,
      voucherContract,
      signer,
      redeemer,
      otherAccount,
      publicClient,
    };
  }

  describe('Deployment', function () {
    it('Should deploy the contract', async function () {
      const {voucherContract} = await deployVoucherFixture();
      assert.ok(voucherContract.address, 'Contract address should not be null');
      assert.strictEqual(
        typeof voucherContract.address,
        'string',
        'Contract address should be a string',
      );
    });
  });

  describe('Voucher Redemption', function () {
    const voucherId = 1n;
    const amount = 100n;

    it('Should redeem a valid voucher', async function () {
      const {voucherContract, signer, redeemer, publicClient} =
        await deployVoucherFixture();
      const redeemerAddress = redeemer.account?.address;
      const signerAddress = signer.account?.address;
      const voucherContractAddress = voucherContract.address;

      const signature = await createSignature(
        signer,
        redeemerAddress,
        voucherId,
        amount,
        voucherContractAddress,
      );

      const voucher: {
        signer: `0x${string}`;
        redeemer: `0x${string}`;
        voucherId: bigint;
        amount: bigint;
        signature: `0x${string}`;
      } = {
        signer: signerAddress!,
        redeemer: redeemerAddress!,
        voucherId,
        amount,
        signature,
      };

      const hash = await voucherContract.write.redeemVoucher(
        [
          voucher.signer,
          voucher.redeemer,
          voucher.voucherId,
          voucher.amount,
          voucher.signature,
        ],
        {
          account: redeemer.account,
        },
      );

      const receipt = await publicClient.waitForTransactionReceipt({hash});
      assert.strictEqual(receipt.status, 'success', 'Transaction failed');

      const used = await voucherContract.read.usedVouchers([voucherId]);
      assert.strictEqual(used, true, 'Voucher should be marked as used');
    });

    it('Should fail if the signature is invalid', async function () {
      const {voucherContract, signer, redeemer, otherAccount} =
        await deployVoucherFixture();
      const redeemerAddress = redeemer.account?.address;
      const signerAddress = signer.account?.address;
      const voucherContractAddress = voucherContract.address;

      const signature = await createSignature(
        otherAccount, // Invalid signer
        redeemerAddress,
        voucherId,
        amount,
        voucherContractAddress,
      );

      const voucher: {
        signer: `0x${string}`;
        redeemer: `0x${string}`;
        voucherId: bigint;
        amount: bigint;
        signature: `0x${string}`;
      } = {
        signer: signerAddress!,
        redeemer: redeemerAddress!,
        voucherId,
        amount,
        signature,
      };

      try {
        await voucherContract.write.redeemVoucher(
          [
            voucher.signer,
            voucher.redeemer,
            voucher.voucherId,
            voucher.amount,
            voucher.signature,
          ],
          {
            account: redeemer.account,
          },
        );
        assert.fail('Transaction should have failed');
      } catch (error: any) {
        assert.ok(
          error.message.includes('Invalid signature'),
          `Expected "Invalid signature" error, but got: ${error.message}`,
        );
      }
    });

    it('Should fail if the voucher is already redeemed', async function () {
      const {voucherContract, signer, redeemer} = await deployVoucherFixture();
      const redeemerAddress = redeemer.account?.address;
      const signerAddress = signer.account?.address;
      const voucherContractAddress = voucherContract.address;

      const signature = await createSignature(
        signer,
        redeemerAddress,
        voucherId,
        amount,
        voucherContractAddress,
      );

      const voucher: {
        signer: `0x${string}`;
        redeemer: `0x${string}`;
        voucherId: bigint;
        amount: bigint;
        signature: `0x${string}`;
      } = {
        signer: signerAddress!,
        redeemer: redeemerAddress!,
        voucherId,
        amount,
        signature,
      };

      await voucherContract.write.redeemVoucher(
        [
          voucher.signer,
          voucher.redeemer,
          voucher.voucherId,
          voucher.amount,
          voucher.signature,
        ],
        {
          account: redeemer.account,
        },
      );

      try {
        await voucherContract.write.redeemVoucher(
          [
            voucher.signer,
            voucher.redeemer,
            voucher.voucherId,
            voucher.amount,
            voucher.signature,
          ],
          {
            account: redeemer.account,
          },
        );
        assert.fail('Transaction should have failed');
      } catch (error: any) {
        assert.ok(
          error.message.includes('Voucher already redeemed'),
          `Expected "Voucher already redeemed" error, but got: ${error.message}`,
        );
      }
    });

    it('Should fail if the redeemer is not the one specified in the signature', async function () {
      const {voucherContract, signer, redeemer, otherAccount} =
        await deployVoucherFixture();
      const redeemerAddress = redeemer.account?.address;
      const signerAddress = signer.account?.address;
      const voucherContractAddress = voucherContract.address;

      const signature = await createSignature(
        signer,
        redeemerAddress,
        voucherId,
        amount,
        voucherContractAddress,
      );

      const voucher: {
        signer: `0x${string}`;
        redeemer: `0x${string}`;
        voucherId: bigint;
        amount: bigint;
        signature: `0x${string}`;
      } = {
        signer: signerAddress!,
        redeemer: redeemerAddress!,
        voucherId,
        amount,
        signature,
      };

      try {
        await voucherContract.write.redeemVoucher(
          [
            voucher.signer,
            voucher.redeemer,
            voucher.voucherId,
            voucher.amount,
            voucher.signature,
          ],
          {
            account: otherAccount.account, // Invalid redeemer
          },
        );
        assert.fail('Transaction should have failed');
      } catch (error: any) {
        assert.ok(
          error.message.includes('Only the specified redeemer can call this'),
          `Expected "Only the specified redeemer can call this" error, but got: ${error.message}`,
        );
      }
    });
  });
});
