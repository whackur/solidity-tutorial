import {
  createPublicClient,
  createWalletClient,
  defineChain,
  http,
  parseEther,
  isAddress,
} from "https://cdn.jsdelivr.net/npm/viem@2/+esm";
import { privateKeyToAccount } from "https://cdn.jsdelivr.net/npm/viem@2/accounts/+esm";

// anvil's RPC port is read from addresses.json (entrypoint writes whatever
// ANVIL_PORT it was started with) and combined with the current page's
// hostname, so the same UI works from localhost, LAN IPs, or VPN.
// Faucet wallet is derived from ANVIL_MNEMONIC at container boot (entrypoint
// picks account #9 to avoid nonce contention with the deployer) and exposed
// via addresses.json. Valid only on the local anvil chain.
const DROP = parseEther("1");
let rpcUrl = null;
let chainId = null;
let faucet = null;

const $addr = document.getElementById("addr");
const $btn = document.getElementById("claim");
const $status = document.getElementById("status");
const $infoRpc = document.getElementById("info-rpc");
const $infoChain = document.getElementById("info-chain");
const $infoDeployer = document.getElementById("info-deployer");
const $infoFaucet = document.getElementById("info-faucet");

function setStatus(text, cls = "") {
  $status.textContent = text;
  $status.className = cls;
}

$btn.addEventListener("click", async () => {
  const to = $addr.value.trim();
  if (!isAddress(to)) {
    setStatus("Invalid address — expected 0x followed by 40 hex chars.", "err");
    return;
  }
  if (!rpcUrl || !chainId || !faucet?.privateKey) {
    setStatus("Not ready yet — refresh after the deploy logs finish.", "err");
    return;
  }

  $btn.disabled = true;
  setStatus("Submitting transaction…");

  try {
    const chain = defineChain({
      id: chainId,
      name: "Anvil",
      nativeCurrency: { name: "Ether", symbol: "ETH", decimals: 18 },
      rpcUrls: { default: { http: [rpcUrl] } },
    });
    const account = privateKeyToAccount(faucet.privateKey);
    const walletClient = createWalletClient({
      account,
      chain,
      transport: http(rpcUrl),
    });
    const publicClient = createPublicClient({
      chain,
      transport: http(rpcUrl),
    });

    const hash = await walletClient.sendTransaction({ to, value: DROP });
    setStatus(`Sent. Waiting for confirmation… ${hash}`);
    await publicClient.waitForTransactionReceipt({ hash });
    setStatus(`Delivered 1 ETH to ${to} (tx ${hash})`, "ok");
  } catch (e) {
    setStatus(`Error: ${e?.shortMessage || e?.message || String(e)}`, "err");
  } finally {
    $btn.disabled = false;
  }
});

$addr.addEventListener("keydown", (e) => {
  if (e.key === "Enter") $btn.click();
});

// --- deployed challenge list -------------------------------------------------
async function loadChallenges() {
  const $container = document.getElementById("challenges");
  try {
    const res = await fetch("./data/addresses.json", { cache: "no-store" });
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    const data = await res.json();
    if (data.rpcPort) {
      rpcUrl = `${location.protocol}//${location.hostname}:${data.rpcPort}`;
      $infoRpc.textContent = rpcUrl;
    }
    if (data.chainId != null) {
      chainId = data.chainId;
      $infoChain.textContent = String(data.chainId);
    }
    if (data.deployer) $infoDeployer.textContent = data.deployer;
    if (data.faucet?.address) $infoFaucet.textContent = data.faucet.address;
    if (data.faucet?.privateKey) faucet = data.faucet;
    renderChallenges($container, data.challenges || {});
  } catch (e) {
    $container.textContent =
      `Addresses not ready yet (${e.message}). The deploy runs ~30s after container boot — refresh shortly.`;
  }
}

function renderChallenges($container, challenges) {
  $container.innerHTML = "";
  const table = document.createElement("table");
  table.className = "ch-table";

  for (const [pkg, addrs] of Object.entries(challenges)) {
    const entries = Object.entries(addrs);
    entries.forEach(([role, addr], i) => {
      const tr = document.createElement("tr");

      const pkgCell = document.createElement("td");
      pkgCell.className = "pkg";
      pkgCell.textContent = i === 0 ? pkg : "";

      const roleCell = document.createElement("td");
      roleCell.className = "role";
      roleCell.textContent = role;

      const addrCell = document.createElement("td");
      addrCell.className = "addr";
      addrCell.textContent = addr;

      const copyCell = document.createElement("td");
      copyCell.className = "copy";
      const copyBtn = document.createElement("button");
      copyBtn.type = "button";
      copyBtn.className = "copy-btn";
      copyBtn.textContent = "Copy";
      copyBtn.addEventListener("click", () => copyAddress(copyBtn, addr));
      copyCell.append(copyBtn);

      tr.append(pkgCell, roleCell, addrCell, copyCell);
      table.append(tr);
    });
  }
  $container.append(table);
}

function copyAddress(btn, value) {
  navigator.clipboard.writeText(value).then(
    () => flashButton(btn, "Copied"),
    () => flashButton(btn, "Failed"),
  );
}

function flashButton(btn, label) {
  const orig = btn.textContent;
  btn.textContent = label;
  btn.classList.add("copied");
  setTimeout(() => {
    btn.textContent = orig;
    btn.classList.remove("copied");
  }, 900);
}

loadChallenges();
