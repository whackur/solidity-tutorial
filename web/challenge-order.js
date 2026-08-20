const STO_CHALLENGE_ORDER = [
  'default-erc-20',
  'simple-wallet',
  'q-05-simple-wallet',
  'thirty-one-game',
  'merkle-allowlist',
  'q-20-erc20-basic',
  'q-27-merkle-allowlist',
];

const STO_CHALLENGE_RANK = new Map(
  STO_CHALLENGE_ORDER.map((packageName, index) => [packageName, index]),
);

export function orderChallengeEntries(challenges) {
  return Object.entries(challenges).sort(([left], [right]) => {
    const leftRank = STO_CHALLENGE_RANK.get(left);
    const rightRank = STO_CHALLENGE_RANK.get(right);

    if (leftRank !== undefined || rightRank !== undefined) {
      return (leftRank ?? Number.MAX_SAFE_INTEGER) - (rightRank ?? Number.MAX_SAFE_INTEGER);
    }

    return left.localeCompare(right);
  });
}
