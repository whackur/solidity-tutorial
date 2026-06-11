import {
  createPublicClient,
  createWalletClient,
  defineChain,
  http,
  parseEther,
  isAddress,
} from 'https://esm.sh/viem@2';
import { privateKeyToAccount } from 'https://esm.sh/viem@2/accounts';

// The faucet UI serves one tab per network. Each entry points at a config
// file under ./data/ (the docker/shared mount):
//   - hoodi.json     — written by scripts/deploy.sh after a live deploy,
//   - addresses.json — written by the anvil container entrypoint at boot.
// Tabs only render for files that actually exist; the first available entry
// in this list is selected by default, so hoodi wins when it is deployed.
// Faucet wallets follow the mnemonic-account-#9 convention on every network.
// On live networks the key is published to students by design (classroom
// faucet) — fund it sparingly and only with testnet ETH.
const NETWORKS = [
  {
    id: 'hoodi',
    label: 'Hoodi Testnet',
    chainName: 'Hoodi',
    file: './data/hoodi.json',
    // Student-facing default; an rpcUrl in hoodi.json overrides it.
    // publicnode has wildcard CORS and proved steadier than ethpandaops.
    defaultRpcUrl: 'https://ethereum-hoodi-rpc.publicnode.com',
    externalFaucet: {
      label: 'Google Cloud Web3 Faucet (free hoodi ETH)',
      url: 'https://cloud.google.com/application/web3/faucet/ethereum/hoodi',
    },
  },
  {
    id: 'local',
    label: 'Local Anvil',
    chainName: 'Anvil',
    file: './data/addresses.json',
  },
];

const TOKEN_ABI = [
  {
    type: 'function',
    name: 'mint',
    stateMutability: 'nonpayable',
    inputs: [
      { name: 'account', type: 'address' },
      { name: 'amount', type: 'uint256' },
    ],
    outputs: [],
  },
];

// Active-network state, populated by selectNetwork().
let current = null;

const $tabs = document.getElementById('networks');
const $addr = document.getElementById('addr');
const $btn = document.getElementById('claim');
const $btnToken = document.getElementById('claim-token');
const $status = document.getElementById('status');
const $extFaucet = document.getElementById('ext-faucet');
const $extFaucetLink = document.getElementById('ext-faucet-link');
const $infoRpc = document.getElementById('info-rpc');
const $infoChain = document.getElementById('info-chain');
const $infoDeployer = document.getElementById('info-deployer');
const $infoFaucet = document.getElementById('info-faucet');
const $infoToken = document.getElementById('info-token');
const $challenges = document.getElementById('challenges');

function setStatus(text, cls = '') {
  $status.textContent = text;
  $status.className = cls;
}

function resolveRpcUrl(net, data) {
  // Local anvil publishes only its port; the host is wherever this page is
  // served from, so the same UI works from localhost, LAN IPs, or VPN.
  if (data.rpcPort) {
    return `${location.protocol}//${location.hostname}:${data.rpcPort}`;
  }
  return data.rpcUrl || net.defaultRpcUrl || null;
}

function makeClients() {
  const chain = defineChain({
    id: current.chainId,
    name: current.net.chainName,
    nativeCurrency: { name: 'Ether', symbol: 'ETH', decimals: 18 },
    rpcUrls: { default: { http: [current.rpcUrl] } },
  });
  const account = privateKeyToAccount(current.faucet.privateKey);
  const walletClient = createWalletClient({
    account,
    chain,
    transport: http(current.rpcUrl),
  });
  const publicClient = createPublicClient({
    chain,
    transport: http(current.rpcUrl),
  });
  return { walletClient, publicClient };
}

function requireReady(needToken) {
  const to = $addr.value.trim();
  if (!isAddress(to)) {
    setStatus('Invalid address — expected 0x followed by 40 hex chars.', 'err');
    return null;
  }
  if (
    !current?.rpcUrl ||
    !current?.chainId ||
    !current?.faucet?.privateKey ||
    (needToken && !current?.sharedToken?.address)
  ) {
    setStatus('Not ready yet — refresh after the deploy logs finish.', 'err');
    return null;
  }
  return to;
}

$btn.addEventListener('click', async () => {
  const to = requireReady(false);
  if (!to) return;

  $btn.disabled = true;
  $btnToken.disabled = true;
  setStatus('Submitting transaction…');

  try {
    const { walletClient, publicClient } = makeClients();
    if (current.maxBalance != null) {
      const balance = await publicClient.getBalance({ address: to });
      if (balance >= current.maxBalance) {
        setStatus(`Refused: ${to} already holds ${current.maxBalanceEth} ETH or more.`, 'err');
        return;
      }
    }
    const hash = await walletClient.sendTransaction({
      to,
      value: current.drop,
    });
    setStatus(`Sent. Waiting for confirmation… ${hash}`);
    await publicClient.waitForTransactionReceipt({ hash });
    setStatus(`Delivered ${current.dropEth} ETH to ${to} (tx ${hash})`, 'ok');
  } catch (e) {
    setStatus(`Error: ${e?.shortMessage || e?.message || String(e)}`, 'err');
  } finally {
    $btn.disabled = false;
    $btnToken.disabled = false;
  }
});

$btnToken.addEventListener('click', async () => {
  const to = requireReady(true);
  if (!to) return;

  $btn.disabled = true;
  $btnToken.disabled = true;
  setStatus('Submitting transaction…');

  try {
    const { walletClient, publicClient } = makeClients();
    const hash = await walletClient.writeContract({
      address: current.sharedToken.address,
      abi: TOKEN_ABI,
      functionName: 'mint',
      args: [to, parseEther('100')],
    });
    setStatus(`Sent. Waiting for confirmation… ${hash}`);
    await publicClient.waitForTransactionReceipt({ hash });
    setStatus(`Delivered 100 ${current.sharedToken.symbol} to ${to} (tx ${hash})`, 'ok');
  } catch (e) {
    setStatus(`Error: ${e?.shortMessage || e?.message || String(e)}`, 'err');
  } finally {
    $btn.disabled = false;
    $btnToken.disabled = false;
  }
});

$addr.addEventListener('keydown', (e) => {
  if (e.key === 'Enter') $btn.click();
});

function selectNetwork(net, data) {
  const dropEth = data.dropEth ?? 1;
  // Live networks cap the ETH drop: recipients already holding at least
  // maxRecipientBalanceEth are refused so the faucet is not drained.
  const maxBalanceEth = data.maxRecipientBalanceEth ?? null;
  current = {
    net,
    data,
    chainId: data.chainId ?? null,
    rpcUrl: resolveRpcUrl(net, data),
    faucet: data.faucet?.privateKey ? data.faucet : null,
    sharedToken: data.sharedToken?.address ? data.sharedToken : null,
    dropEth,
    drop: parseEther(String(dropEth)),
    maxBalanceEth,
    maxBalance: maxBalanceEth != null ? parseEther(String(maxBalanceEth)) : null,
  };

  for (const btn of $tabs.querySelectorAll('button')) {
    btn.classList.toggle('active', btn.dataset.network === net.id);
  }

  $infoRpc.textContent = current.rpcUrl || '—';
  $infoChain.textContent = current.chainId != null ? String(current.chainId) : '—';
  $infoDeployer.textContent = data.deployer || '—';
  $infoFaucet.textContent = current.faucet?.address || data.faucet?.address || '—';
  $btn.textContent = `Send ${current.dropEth} ETH`;
  if (current.sharedToken) {
    $infoToken.textContent = `${current.sharedToken.address} (${current.sharedToken.symbol})`;
    $btnToken.textContent = `Send 100 ${current.sharedToken.symbol}`;
    $btnToken.hidden = false;
  } else {
    $infoToken.textContent = '—';
    $btnToken.hidden = true;
  }

  if (net.externalFaucet) {
    $extFaucetLink.textContent = net.externalFaucet.label;
    $extFaucetLink.href = net.externalFaucet.url;
    $extFaucet.hidden = false;
  } else {
    $extFaucet.hidden = true;
  }

  setStatus('');
  renderChallenges($challenges, data.challenges || {});
}

async function loadNetworks() {
  const loaded = [];
  for (const net of NETWORKS) {
    try {
      const res = await fetch(net.file, { cache: 'no-store' });
      if (!res.ok) continue;
      loaded.push({ net, data: await res.json() });
    } catch {
      // missing config file — network simply not offered
    }
  }

  if (loaded.length === 0) {
    $challenges.textContent =
      'Addresses not ready yet. The deploy runs ~30s after container boot — refresh shortly.';
    return;
  }

  $tabs.innerHTML = '';
  for (const entry of loaded) {
    const btn = document.createElement('button');
    btn.type = 'button';
    btn.dataset.network = entry.net.id;
    btn.textContent = entry.net.label;
    btn.addEventListener('click', () => selectNetwork(entry.net, entry.data));
    $tabs.append(btn);
  }
  $tabs.hidden = loaded.length < 2;

  selectNetwork(loaded[0].net, loaded[0].data);
}

function renderChallenges($container, challenges) {
  $container.innerHTML = '';
  const table = document.createElement('table');
  table.className = 'ch-table';

  for (const [pkg, addrs] of Object.entries(challenges)) {
    const entries = Object.entries(addrs);
    entries.forEach(([role, addr], i) => {
      const tr = document.createElement('tr');

      const pkgCell = document.createElement('td');
      pkgCell.className = 'pkg';
      pkgCell.textContent = i === 0 ? pkg : '';

      const roleCell = document.createElement('td');
      roleCell.className = 'role';
      roleCell.textContent = role;

      const addrCell = document.createElement('td');
      addrCell.className = 'addr';
      addrCell.textContent = addr;

      const copyCell = document.createElement('td');
      copyCell.className = 'copy';
      const copyBtn = document.createElement('button');
      copyBtn.type = 'button';
      copyBtn.className = 'copy-btn';
      copyBtn.textContent = 'Copy';
      copyBtn.addEventListener('click', () => copyAddress(copyBtn, addr));
      copyCell.append(copyBtn);

      tr.append(pkgCell, roleCell, addrCell, copyCell);
      table.append(tr);
    });
  }
  $container.append(table);
}

function copyAddress(btn, value) {
  navigator.clipboard.writeText(value).then(
    () => flashButton(btn, 'Copied'),
    () => flashButton(btn, 'Failed'),
  );
}

function flashButton(btn, label) {
  const orig = btn.textContent;
  btn.textContent = label;
  btn.classList.add('copied');
  setTimeout(() => {
    btn.textContent = orig;
    btn.classList.remove('copied');
  }, 900);
}

loadNetworks();
