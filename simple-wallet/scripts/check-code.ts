import {network} from 'hardhat';

async function main() {
  const {viem} = await network.connect({network: 'holesky', chainType: 'l1'});
  const publicClient = await viem.getPublicClient();

  // 확인할 컨트랙트 주소
  const address = '0x05eb5def5fd6897cdab55e039b9a874faf908ae2'; // SimpleWallet

  console.log(`Checking code at address: ${address}`);

  const code = await publicClient.getBytecode({address});

  if (code === '0x' || code === undefined) {
    console.log('No code found at this address.');
  } else {
    console.log('Code found at this address:');
    console.log(code);
  }
}

main().catch((error) => {
  console.error(error);
  process.exitCode = 1;
});
