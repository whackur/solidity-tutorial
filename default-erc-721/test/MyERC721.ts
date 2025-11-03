import {describe, it} from 'node:test';
import {expect} from 'chai';
import {network} from 'hardhat';
import {getAddress} from 'viem/utils';

describe('MyERC721', function () {
  async function deployMyERC721Fixture() {
    const {viem} = await network.connect();
    const [owner, otherAccount] = await viem.getWalletClients();

    const myERC721 = await viem.deployContract('MyERC721', ['MyERC721', 'ME7']);

    const publicClient = await viem.getPublicClient();

    return {
      myERC721,
      owner,
      otherAccount,
      publicClient,
    };
  }

  describe('Deployment', function () {
    it('Should set the right name and symbol', async function () {
      const {myERC721} = await deployMyERC721Fixture();

      expect(await myERC721.read.name()).to.equal('MyERC721');
      expect(await myERC721.read.symbol()).to.equal('ME7');
    });
  });

  describe('Minting', function () {
    it('Should mint a new token and assign it to the owner', async function () {
      const {myERC721, owner} = await deployMyERC721Fixture();
      const ownerAddress = getAddress(owner.account.address);

      const tokenId = 0n;
      await myERC721.write.safeMint([ownerAddress, '']);

      const balance = await myERC721.read.balanceOf([ownerAddress]);
      expect(balance).to.equal(1n);

      expect(await myERC721.read.ownerOf([tokenId])).to.equal(ownerAddress);
    });
  });
});
