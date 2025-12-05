import {buildModule} from '@nomicfoundation/hardhat-ignition/modules';

const SignatureVerifierModule = buildModule('SignatureVerifierModule', (m) => {
  const signatureVerifier = m.contract('SignatureVerifier');

  return {signatureVerifier};
});

export default SignatureVerifierModule;
