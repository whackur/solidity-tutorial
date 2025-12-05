import {describe, it} from 'node:test';
import {expect} from 'chai';
import {network} from 'hardhat';
import {keccak256, toBytes, toHex} from 'viem';

describe('Signature Verifier', function () {
  async function deploySignatureVerifierFixture() {
    const {viem} = await network.connect();
    const [owner, signer, otherAccount] = await viem.getWalletClients();

    const signatureVerifier = await viem.deployContract('SignatureVerifier');

    const publicClient = await viem.getPublicClient();

    return {
      viem,
      signatureVerifier,
      owner,
      signer,
      otherAccount,
      publicClient,
    };
  }

  describe('Deployment', function () {
    it('Should deploy successfully', async function () {
      const {signatureVerifier} = await deploySignatureVerifierFixture();
      expect(signatureVerifier.address).to.be.a('string');
      expect(signatureVerifier.address).to.have.lengthOf(42);
    });
  });

  describe('eth_sign Verification', function () {
    it('Should verify eth_sign signature correctly', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const message = 'Hello, Ethereum!';
      const messageHash = keccak256(toBytes(message));

      const signature = await signer.signMessage({
        message: {raw: messageHash},
      });

      const recoveredSigner = await (
        signatureVerifier.read as any
      ).verifyEthSign([messageHash, signature]);

      expect(recoveredSigner.toLowerCase()).to.equal(
        signer.account.address.toLowerCase(),
      );
    });

    it('Should verify eth_sign with expected signer', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const message = 'Test Message';
      const messageHash = keccak256(toBytes(message));

      const signature = await signer.signMessage({
        message: {raw: messageHash},
      });

      const isValid = await (signatureVerifier.read as any).verifyEthSignSigner(
        [messageHash, signature, signer.account.address],
      );

      expect(isValid).to.be.true;
    });

    it('Should fail verification with wrong signer', async function () {
      const {signatureVerifier, signer, otherAccount} =
        await deploySignatureVerifierFixture();

      const message = 'Test Message';
      const messageHash = keccak256(toBytes(message));

      const signature = await signer.signMessage({
        message: {raw: messageHash},
      });

      const isValid = await (signatureVerifier.read as any).verifyEthSignSigner(
        [messageHash, signature, otherAccount.account.address],
      );

      expect(isValid).to.be.false;
    });

    it('Should recover eth_sign signer using pure function', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const messageHash = keccak256(toBytes('Pure function test'));

      const signature = await signer.signMessage({
        message: {raw: messageHash},
      });

      const recoveredSigner = await (
        signatureVerifier.read as any
      ).recoverEthSignSigner([messageHash, signature]);

      expect(recoveredSigner.toLowerCase()).to.equal(
        signer.account.address.toLowerCase(),
      );
    });
  });

  describe('personal_sign Verification', function () {
    it('Should verify personal_sign signature correctly', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const message = 'Hello, Ethereum Personal Sign!';

      const signature = await signer.signMessage({
        message: message,
      });

      const messageHex = toHex(toBytes(message));

      const recoveredSigner = await (
        signatureVerifier.read as any
      ).verifyPersonalSign([messageHex, signature]);

      expect(recoveredSigner.toLowerCase()).to.equal(
        signer.account.address.toLowerCase(),
      );
    });

    it('Should verify personal_sign with expected signer', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const message = 'Test Personal Sign';

      const signature = await signer.signMessage({
        message: message,
      });

      const messageHex = toHex(toBytes(message));

      const isValid = await (
        signatureVerifier.read as any
      ).verifyPersonalSignSigner([
        messageHex,
        signature,
        signer.account.address,
      ]);

      expect(isValid).to.be.true;
    });

    it('Should fail verification with wrong signer', async function () {
      const {signatureVerifier, signer, otherAccount} =
        await deploySignatureVerifierFixture();

      const message = 'Test Personal Sign Fail';

      const signature = await signer.signMessage({
        message: message,
      });

      const messageHex = toHex(toBytes(message));

      const isValid = await (
        signatureVerifier.read as any
      ).verifyPersonalSignSigner([
        messageHex,
        signature,
        otherAccount.account.address,
      ]);

      expect(isValid).to.be.false;
    });

    it('Should recover personal_sign signer using pure function', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const message = 'Pure function personal sign test';

      const signature = await signer.signMessage({
        message: message,
      });

      const messageHex = toHex(toBytes(message));

      const recoveredSigner = await (
        signatureVerifier.read as any
      ).recoverPersonalSignSigner([messageHex, signature]);

      expect(recoveredSigner.toLowerCase()).to.equal(
        signer.account.address.toLowerCase(),
      );
    });

    it('Should handle UTF-8 messages correctly', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const message = '안녕하세요, 이더리움!';

      const signature = await signer.signMessage({
        message: message,
      });

      const messageHex = toHex(toBytes(message));

      const recoveredSigner = await (
        signatureVerifier.read as any
      ).verifyPersonalSign([messageHex, signature]);

      expect(recoveredSigner.toLowerCase()).to.equal(
        signer.account.address.toLowerCase(),
      );
    });
  });

  describe('Event Emission', function () {
    it('Should emit SignatureVerified event for eth_sign', async function () {
      const {signatureVerifier, signer, publicClient, owner} =
        await deploySignatureVerifierFixture();

      const messageHash = keccak256(toBytes('Event test'));
      const signature = await signer.signMessage({
        message: {raw: messageHash},
      });

      const hash = await (signatureVerifier.write as any).verifyEthSign(
        [messageHash, signature],
        {account: owner.account},
      );

      const receipt = await publicClient.waitForTransactionReceipt({hash});

      expect(receipt.logs.length).to.be.greaterThan(0);
    });

    it('Should emit SignatureVerified event for personal_sign', async function () {
      const {signatureVerifier, signer, publicClient, owner} =
        await deploySignatureVerifierFixture();

      const message = 'Event test personal';
      const messageHex = toHex(toBytes(message));
      const signature = await signer.signMessage({message});

      const hash = await (signatureVerifier.write as any).verifyPersonalSign(
        [messageHex, signature],
        {account: owner.account},
      );

      const receipt = await publicClient.waitForTransactionReceipt({hash});

      expect(receipt.logs.length).to.be.greaterThan(0);
    });
  });
});
