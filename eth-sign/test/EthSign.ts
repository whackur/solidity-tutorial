import {describe, it} from 'node:test';
import {expect} from 'chai';
import {network} from 'hardhat';
import {getAddress, encodePacked, keccak256, toBytes, toHex, Hex} from 'viem';

describe('EthSign', function () {
  async function deployEthSignFixture() {
    const {viem} = await network.connect();
    const [owner, otherAccount] = await viem.getWalletClients();
    const publicClient = await viem.getPublicClient();

    const ethSign = await viem.deployContract('EthSign');

    return {
      ethSign,
      publicClient,
      owner,
      otherAccount,
    };
  }

  describe('recoverEthSign', function () {
    it('should recover the signer address from an eth_sign signature', async function () {
      const {ethSign, owner} = await deployEthSignFixture();

      const message = 'Hello, world!';
      const messageHash = keccak256(encodePacked(['string'], [message]));

      // Use the wallet client's request method for the raw JSON-RPC call
      const signature = await owner.request({
        method: 'eth_sign',
        params: [owner.account.address, messageHash],
      });

      const recoveredAddress = await ethSign.read.recoverEthSign([
        messageHash,
        signature,
      ]);

      expect(getAddress(recoveredAddress)).to.equal(
        getAddress(owner.account.address),
      );
    });
  });

  describe('recoverPersonalSign', function () {
    it('should recover the signer address from a personal_sign signature', async function () {
      const {ethSign, owner} = await deployEthSignFixture();

      const message = 'Hello, personal_sign!';
      const messageBytes = toHex(toBytes(message));

      // signMessage performs personal_sign
      const signature = await owner.signMessage({
        message: message,
      });

      const recoveredAddress = await ethSign.read.recoverPersonalSign([
        messageBytes,
        signature,
      ]);

      expect(getAddress(recoveredAddress)).to.equal(
        getAddress(owner.account.address),
      );
    });
  });
});
