import {describe, it} from 'node:test';
import {expect} from 'chai';
import {network} from 'hardhat';
import {bytesToHex, keccak256, toBytes} from 'viem';
import type {Hex} from 'viem';

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
    it('Should recover eth_sign signer correctly', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const message = 'Hello, Ethereum!';
      const messageHash = keccak256(toBytes(message));

      const signature = await signer.signMessage({
        message: {raw: messageHash},
      });

      const recoveredSigner =
        (await signatureVerifier.read.recoverEthSignSigner([
          messageHash,
          signature,
        ])) as Hex;

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

      const isValid = await signatureVerifier.read.verifyEthSign([
        messageHash,
        signature,
        signer.account.address,
      ]);

      expect(isValid).to.equal(true);
    });

    it('Should fail verification with wrong signer', async function () {
      const {signatureVerifier, signer, otherAccount} =
        await deploySignatureVerifierFixture();

      const message = 'Test Message';
      const messageHash = keccak256(toBytes(message));

      const signature = await signer.signMessage({
        message: {raw: messageHash},
      });

      const isValid = await signatureVerifier.read.verifyEthSign([
        messageHash,
        signature,
        otherAccount.account.address,
      ]);

      expect(isValid).to.equal(false);
    });

    it('Should recover eth_sign signer using pure function', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const messageHash = keccak256(toBytes('Pure function test'));

      const signature = await signer.signMessage({
        message: {raw: messageHash},
      });

      const recoveredSigner =
        (await signatureVerifier.read.recoverEthSignSigner([
          messageHash,
          signature,
        ])) as Hex;

      expect(recoveredSigner.toLowerCase()).to.equal(
        signer.account.address.toLowerCase(),
      );
    });
  });

  describe('personal_sign Verification', function () {
    it('Should recover personal_sign signer correctly', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const message = 'Hello, Ethereum Personal Sign!';

      const signature = await signer.signMessage({
        message: message,
      });

      const messageBytes = bytesToHex(toBytes(message));

      const recoveredSigner =
        (await signatureVerifier.read.recoverPersonalSignSigner([
          messageBytes,
          signature,
        ])) as Hex;

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

      const messageBytes = bytesToHex(toBytes(message));

      const isValid = await signatureVerifier.read.verifyPersonalSign([
        messageBytes,
        signature,
        signer.account.address,
      ]);

      expect(isValid).to.equal(true);
    });

    it('Should fail verification with wrong signer', async function () {
      const {signatureVerifier, signer, otherAccount} =
        await deploySignatureVerifierFixture();

      const message = 'Test Personal Sign Fail';

      const signature = await signer.signMessage({
        message: message,
      });

      const messageBytes = bytesToHex(toBytes(message));

      const isValid = await signatureVerifier.read.verifyPersonalSign([
        messageBytes,
        signature,
        otherAccount.account.address,
      ]);

      expect(isValid).to.equal(false);
    });

    it('Should recover personal_sign signer using pure function', async function () {
      const {signatureVerifier, signer} =
        await deploySignatureVerifierFixture();

      const message = 'Pure function personal sign test';

      const signature = await signer.signMessage({
        message: message,
      });

      const messageBytes = bytesToHex(toBytes(message));

      const recoveredSigner =
        (await signatureVerifier.read.recoverPersonalSignSigner([
          messageBytes,
          signature,
        ])) as Hex;

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

      const messageBytes = bytesToHex(toBytes(message));

      const recoveredSigner =
        (await signatureVerifier.read.recoverPersonalSignSigner([
          messageBytes,
          signature,
        ])) as Hex;

      expect(recoveredSigner.toLowerCase()).to.equal(
        signer.account.address.toLowerCase(),
      );
    });
  });
});
