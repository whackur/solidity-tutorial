import {
  JsonRpcProvider,
  Wallet,
  parseEther,
  isAddress,
} from "https://cdn.jsdelivr.net/npm/ethers@6/+esm";

// anvil exposes its RPC on the same host the page is served from, port 8545.
// Works whether the page is opened as http://localhost:8080/ or via the
// instructor's LAN IP.
const RPC_URL = `${location.protocol}//${location.hostname}:8545`;

// Faucet wallet is derived from ANVIL_MNEMONIC at container boot (entrypoint
// picks account #9 to avoid nonce contention with the deployer) and exposed
// via addresses.json. Valid only on the local anvil chain.
const DROP = parseEther("1");
let faucet = null;

const $addr = document.getElementById("addr");
const $btn = document.getElementById("claim");
const $status = document.getElementById("status");
const $infoRpc = document.getElementById("info-rpc");
const $infoChain = document.getElementById("info-chain");
const $infoDeployer = document.getElementById("info-deployer");
const $infoFaucet = document.getElementById("info-faucet");

$infoRpc.textContent = RPC_URL;

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
  if (!faucet?.privateKey) {
    setStatus("Faucet not ready — refresh after the deploy logs finish.", "err");
    return;
  }

  $btn.disabled = true;
  setStatus("Submitting transaction…");

  try {
    const provider = new JsonRpcProvider(RPC_URL);
    const wallet = new Wallet(faucet.privateKey, provider);
    const tx = await wallet.sendTransaction({ to, value: DROP });
    setStatus(`Sent. Waiting for confirmation… ${tx.hash}`);
    await tx.wait();
    setStatus(`Delivered 1 ETH to ${to} (tx ${tx.hash})`, "ok");
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
    if (data.chainId != null) $infoChain.textContent = String(data.chainId);
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
