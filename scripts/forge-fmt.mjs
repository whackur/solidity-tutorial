import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import process from 'node:process';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(SCRIPT_DIR, '..');
const TARGETS = [
  'default-erc-20/src',
  'default-erc-20/test',
  'default-erc-20/script',
  'default-erc-721/src',
  'default-erc-721/test',
  'default-erc-721/script',
  'eip-712-voucher/src',
  'eip-712-voucher/test',
  'eip-712-voucher/script',
  'erc20-roles/src',
  'erc20-roles/test',
  'erc20-roles/script',
  'eth-sign/src',
  'eth-sign/test',
  'eth-sign/script',
  'minimal-proxy/src',
  'minimal-proxy/test',
  'minimal-proxy/script',
  'simple-transparent/src',
  'simple-transparent/test',
  'simple-transparent/script',
  'simple-uups/src',
  'simple-uups/test',
  'simple-uups/script',
  'simple-wallet/src',
  'simple-wallet/test',
  'simple-wallet/script',
  'thirty-one-game/src',
  'thirty-one-game/test',
  'thirty-one-game/script',
];

const args = [
  'fmt',
  '--root',
  '.',
  ...(process.argv.includes('--check') ? ['--check'] : []),
  ...TARGETS,
];
const child = spawn('forge', args, { cwd: ROOT, stdio: 'inherit', shell: process.platform === 'win32' });
child.on('exit', (code) => process.exit(code ?? 1));
