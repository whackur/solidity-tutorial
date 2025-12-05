import {describe, it} from 'node:test';
import assert from 'node:assert/strict';
import {network} from 'hardhat';
import {createSignature} from './lib/utils.js';

describe('Voucher', function () {
  async function deployVoucherFixture() {
    const {viem} = await network.connect();
    const [signer, redeemer, otherAccount] = await viem.getWalletClients();

    const tokenContract = await viem.deployContract('MyERC20', [
      'My Test Token',
      'MTT',
      1000000n,
    ]);
    const voucherContract = await viem.deployContract('Voucher');
    const publicClient = await viem.getPublicClient();

    return {
      viem,
      voucherContract,
      tokenContract,
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
      const {voucherContract, tokenContract, signer, redeemer, publicClient} =
        await deployVoucherFixture();
      const redeemerAddress = redeemer.account.address;
      const signerAddress = signer.account.address;
      const voucherContractAddress = voucherContract.address;
      const tokenContractAddress = tokenContract.address;

      await tokenContract.write.approve([voucherContractAddress, amount], {
        account: signer.account,
      });

      const signature = await createSignature(
        signer,
        tokenContractAddress,
        redeemerAddress,
        voucherId,
        amount,
        voucherContractAddress,
      );

      const voucher: {
        token: `0x${string}`;
        signer: `0x${string}`;
        redeemer: `0x${string}`;
        voucherId: bigint;
        amount: bigint;
        signature: `0x${string}`;
      } = {
        token: tokenContractAddress,
        signer: signerAddress,
        redeemer: redeemerAddress,
        voucherId,
        amount,
        signature,
      };

      const initialRedeemerBalance = await tokenContract.read.balanceOf([
        redeemerAddress,
      ]);

      const hash = await voucherContract.write.redeemVoucher(
        [
          voucher.token,
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

      const finalRedeemerBalance = await tokenContract.read.balanceOf([
        redeemerAddress,
      ]);
      assert.strictEqual(
        finalRedeemerBalance,
        initialRedeemerBalance + amount,
        'Redeemer balance should be increased by the voucher amount',
      );
    });

    it('Should fail if the signature is invalid', async function () {
      const {voucherContract, tokenContract, signer, redeemer, otherAccount} =
        await deployVoucherFixture();
      const redeemerAddress = redeemer.account.address;
      const signerAddress = signer.account.address;
      const voucherContractAddress = voucherContract.address;
      const tokenContractAddress = tokenContract.address;

      const signature = await createSignature(
        otherAccount, // Invalid signer
        tokenContractAddress,
        redeemerAddress,
        voucherId,
        amount,
        voucherContractAddress,
      );

      const voucher: {
        token: `0x${string}`;
        signer: `0x${string}`;
        redeemer: `0x${string}`;
        voucherId: bigint;
        amount: bigint;
        signature: `0x${string}`;
      } = {
        token: tokenContractAddress,
        signer: signerAddress,
        redeemer: redeemerAddress,
        voucherId,
        amount,
        signature,
      };

      try {
        await voucherContract.write.redeemVoucher(
          [
            voucher.token,
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
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : String(error);
        assert.ok(
          errorMessage.includes('Invalid signature'),
          `Expected "Invalid signature" error, but got: ${errorMessage}`,
        );
      }
    });

    it('Should fail if the voucher is already redeemed', async function () {
      const {voucherContract, tokenContract, signer, redeemer} =
        await deployVoucherFixture();
      const redeemerAddress = redeemer.account.address;
      const signerAddress = signer.account.address;
      const voucherContractAddress = voucherContract.address;
      const tokenContractAddress = tokenContract.address;

      await tokenContract.write.approve([voucherContractAddress, amount], {
        account: signer.account,
      });

      const signature = await createSignature(
        signer,
        tokenContractAddress,
        redeemerAddress,
        voucherId,
        amount,
        voucherContractAddress,
      );

      const voucher: {
        token: `0x${string}`;
        signer: `0x${string}`;
        redeemer: `0x${string}`;
        voucherId: bigint;
        amount: bigint;
        signature: `0x${string}`;
      } = {
        token: tokenContractAddress,
        signer: signerAddress,
        redeemer: redeemerAddress,
        voucherId,
        amount,
        signature,
      };

      await voucherContract.write.redeemVoucher(
        [
          voucher.token,
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
            voucher.token,
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
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : String(error);
        assert.ok(
          errorMessage.includes('Voucher already redeemed'),
          `Expected "Voucher already redeemed" error, but got: ${errorMessage}`,
        );
      }
    });

    it('Should fail if the redeemer is not the one specified in the signature', async function () {
      const {voucherContract, tokenContract, signer, redeemer, otherAccount} =
        await deployVoucherFixture();
      const redeemerAddress = redeemer.account.address;
      const signerAddress = signer.account.address;
      const voucherContractAddress = voucherContract.address;
      const tokenContractAddress = tokenContract.address;

      const signature = await createSignature(
        signer,
        tokenContractAddress,
        redeemerAddress,
        voucherId,
        amount,
        voucherContractAddress,
      );

      const voucher: {
        token: `0x${string}`;
        signer: `0x${string}`;
        redeemer: `0x${string}`;
        voucherId: bigint;
        amount: bigint;
        signature: `0x${string}`;
      } = {
        token: tokenContractAddress,
        signer: signerAddress,
        redeemer: redeemerAddress,
        voucherId,
        amount,
        signature,
      };

      try {
        await voucherContract.write.redeemVoucher(
          [
            voucher.token,
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
      } catch (error) {
        const errorMessage =
          error instanceof Error ? error.message : String(error);
        assert.ok(
          errorMessage.includes('Only the specified redeemer can call this'),
          `Expected "Only the specified redeemer can call this" error, but got: ${errorMessage}`,
        );
      }
    });
  });
});
