import {describe, it} from 'node:test';
import {expect} from 'chai';
import {network} from 'hardhat';
import {getAddress} from 'viem/utils';

describe('MyERC20', function () {
  async function deployMyERC20Fixture() {
    const {viem} = await network.connect();
    const [owner, otherAccount] = await viem.getWalletClients();

    const myERC20 = await viem.deployContract('MyERC20', [
      'MyERC20',
      'ME2',
      1000n,
    ]);

    const publicClient = await viem.getPublicClient();

    return {
      viem,
      myERC20,
      owner,
      otherAccount,
      publicClient,
    };
  }

  describe('Deployment', function () {
    it('Should set the right name and symbol', async function () {
      const {myERC20} = await deployMyERC20Fixture();

      expect(await myERC20.read.name()).to.equal('MyERC20');
      expect(await myERC20.read.symbol()).to.equal('ME2');
    });

    it('Should assign the total supply of tokens to the owner', async function () {
      const {myERC20, owner} = await deployMyERC20Fixture();
      const ownerAddress = getAddress(owner.account.address);
      const ownerBalance = await myERC20.read.balanceOf([ownerAddress]);
      expect(await myERC20.read.totalSupply()).to.equal(ownerBalance);
    });
  });

  describe('Transactions', function () {
    it('Should transfer tokens between accounts', async function () {
      const {myERC20, owner, otherAccount, publicClient} =
        await deployMyERC20Fixture();
      const ownerAddress = getAddress(owner.account.address);
      const otherAccountAddress = getAddress(otherAccount.account.address);

      // Transfer 50 tokens from owner to otherAccount
      await myERC20.write.transfer([otherAccountAddress, 50n], {
        account: owner.account,
      });
      const otherAccountBalance = await myERC20.read.balanceOf([
        otherAccountAddress,
      ]);
      expect(otherAccountBalance).to.equal(50n);

      // Transfer 50 tokens from otherAccount to owner
      const hash = await myERC20.write.transfer([ownerAddress, 50n], {
        account: otherAccount.account,
      });
      await publicClient.waitForTransactionReceipt({hash});

      const finalOtherAccountBalance = await myERC20.read.balanceOf([
        otherAccountAddress,
      ]);
      expect(finalOtherAccountBalance).to.equal(0n);

      const newOwnerBalance = await myERC20.read.balanceOf([ownerAddress]);
      expect(newOwnerBalance).to.equal(1000n);
    });
  });
});
