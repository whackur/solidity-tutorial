const BASE_SEPOLIA_CONTRACTS = {
  'transfer-blocklist': {
    token: ['BlocklistRestrictedToken', 'transfer-blocklist/src/BlocklistRestrictedToken.sol'],
    blocklist: ['AddressBlocklist', 'transfer-blocklist/src/AddressBlocklist.sol'],
    restrictedToken: ['BlocklistRestrictedToken', 'transfer-blocklist/src/BlocklistRestrictedToken.sol'],
  },
  counter: {
    counter: ['Counter', 'counter/src/Counter.sol'],
    eventsAndErrors: ['EventsAndErrors', 'counter/src/EventsAndErrors.sol'],
    simpleStorage: ['SimpleStorage', 'counter/src/SimpleStorage.sol'],
  },
  'simple-wallet': {
    wallet: ['SimpleWallet', 'simple-wallet/src/SimpleWallet.sol'],
  },
  'q-01-counter': {
    counter: ['Q01Counter', 'q-01-counter/src/Setup.sol'],
  },
  'q-05-simple-wallet': {
    wallet: ['Q05SimpleWallet', 'q-05-simple-wallet/src/Setup.sol'],
    token: ['BlocklistRestrictedToken', 'transfer-blocklist/src/BlocklistRestrictedToken.sol'],
  },
  'thirty-one-game': {
    token: ['BlocklistRestrictedToken', 'transfer-blocklist/src/BlocklistRestrictedToken.sol'],
    game: ['ThirtyOneGame', 'thirty-one-game/src/ThirtyOneGame.sol'],
  },
  'q-20-erc20-basic': {
    lab: ['Q20Erc20BasicLab', 'q-20-erc20-basic/src/Setup.sol'],
    faucet: ['Q20Faucet', 'q-20-erc20-basic/src/Setup.sol'],
    vault: ['Q20PullVault', 'q-20-erc20-basic/src/Setup.sol'],
  },
  'merkle-allowlist': {
    token: ['BlocklistRestrictedToken', 'transfer-blocklist/src/BlocklistRestrictedToken.sol'],
    allowlist: ['MerkleAllowlist', 'merkle-allowlist/src/MerkleAllowlist.sol'],
    restrictedToken: ['AllowlistRestrictedToken', 'merkle-allowlist/src/AllowlistRestrictedToken.sol'],
    distributor: ['MerkleDistributor', 'merkle-allowlist/src/MerkleDistributor.sol'],
  },
  'q-27-merkle-allowlist': {
    lab: ['Q27MerkleAllowlistLab', 'q-27-merkle-allowlist/src/Setup.sol'],
  },
};

export function getChallengeContract(networkId, packageName, role) {
  if (networkId !== 'base-sepolia') return null;
  const entry = BASE_SEPOLIA_CONTRACTS[packageName]?.[role];
  return entry ? { contractName: entry[0], sourceFile: entry[1] } : null;
}
