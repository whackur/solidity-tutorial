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

// anvil default account #9 — the deploy script uses account #0, so we
// pick a separate account here to avoid nonce contention when many
// students click the faucet at the same time. Both keys are public,
// documented anvil constants; valid only on the local 31337 chain.
const FAUCET_KEY = "0x2a871d0798f97d79848a013d4936a73bf4cc922c825d33c1cf7073dff6d409c6";
const DROP = parseEther("1");

const $addr = document.getElementById("addr");
const $btn = document.getElementById("claim");
const $status = document.getElementById("status");
const $infoRpc = document.getElementById("info-rpc");

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

  $btn.disabled = true;
  setStatus("Submitting transaction…");

  try {
    const provider = new JsonRpcProvider(RPC_URL);
    const wallet = new Wallet(FAUCET_KEY, provider);
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
