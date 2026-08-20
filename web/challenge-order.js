// Tutorial packages come first, the q-* challenge set second. Inside each
// group a curated classroom order wins; anything unlisted falls back to a
// numeric-aware name compare so q-2 never sorts ahead of q-10.
const TUTORIAL_ORDER = ['transfer-blocklist', 'counter', 'simple-wallet', 'thirty-one-game', 'merkle-allowlist'];

const CHALLENGE_ORDER = [
  'q-01-counter',
  'q-05-simple-wallet',
  'q-20-erc20-basic',
  'q-27-merkle-allowlist',
];

const TUTORIAL_RANK = new Map(TUTORIAL_ORDER.map((packageName, index) => [packageName, index]));
const CHALLENGE_RANK = new Map(CHALLENGE_ORDER.map((packageName, index) => [packageName, index]));

const collator = new Intl.Collator('en', { numeric: true, sensitivity: 'base' });

function isChallenge(packageName) {
  return /^q-\d/.test(packageName);
}

function rankOf(packageName) {
  const rank = isChallenge(packageName)
    ? CHALLENGE_RANK.get(packageName)
    : TUTORIAL_RANK.get(packageName);
  return rank ?? Number.MAX_SAFE_INTEGER;
}

export function orderChallengeEntries(challenges) {
  return Object.entries(challenges).sort(([left], [right]) => {
    const groupDelta = Number(isChallenge(left)) - Number(isChallenge(right));
    if (groupDelta !== 0) return groupDelta;

    const rankDelta = rankOf(left) - rankOf(right);
    if (rankDelta !== 0) return rankDelta;

    return collator.compare(left, right);
  });
}
