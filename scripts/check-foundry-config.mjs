import { spawn } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';
import process from 'node:process';

const SCRIPT_DIR = path.dirname(fileURLToPath(import.meta.url));
const script = path.resolve(SCRIPT_DIR, 'generate-foundry-config.mjs');

const child = spawn(process.execPath, [script, '--check'], { stdio: 'inherit' });
child.on('exit', (code) => process.exit(code ?? 1));
