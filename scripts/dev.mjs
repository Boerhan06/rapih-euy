import { spawn, spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { buildEngine, getEngineBinaryPath } from './build-engine.mjs';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const uiDir = path.join(rootDir, 'rapih_ui');
const args = process.argv.slice(2);

const forceWindows = args.includes('--windows');
const forceWeb = args.includes('--web');

function hasVisualStudioCpp() {
  const vswhere = path.join(
    process.env['ProgramFiles(x86)'] || 'C:\\Program Files (x86)',
    'Microsoft Visual Studio',
    'Installer',
    'vswhere.exe'
  );
  if (!fs.existsSync(vswhere)) return false;
  const res = spawnSync(
    vswhere,
    ['-latest', '-products', '*', '-requires', 'Microsoft.VisualStudio.Component.VC.Tools.x86.x64', '-property', 'installationPath'],
    { encoding: 'utf8' }
  );
  return res.status === 0 && res.stdout.trim().length > 0;
}

async function waitForEngineHealth(url, timeoutMs = 8000) {
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    try {
      const res = await fetch(url);
      if (res.ok) return true;
    } catch {
      // retry
    }
    await new Promise((r) => setTimeout(r, 250));
  }
  return false;
}

async function main() {
  console.log('===============================================');
  console.log('   Rapih Euy - Dev Runner (Rust + Flutter)     ');
  console.log('===============================================\n');

  // 1. Build / Start Rust Backend Engine
  let engineBin = buildEngine() || getEngineBinaryPath();
  let engineProc = null;

  if (engineBin && fs.existsSync(engineBin)) {
    console.log(`[Backend] Menjalankan rapih_engine HTTP & RPC server di http://127.0.0.1:8787 ...`);
    engineProc = spawn(engineBin, ['--serve', '8787'], {
      cwd: rootDir,
      stdio: ['ignore', 'pipe', 'pipe'],
    });
    engineProc.stdout.on('data', (d) => process.stdout.write(`[Rust] ${d}`));
    engineProc.stderr.on('data', (d) => process.stderr.write(`[Rust Err] ${d}`));

    const healthy = await waitForEngineHealth('http://127.0.0.1:8787/health');
    if (healthy) {
      console.log('[Backend] Rust Engine LIVE dan siap menerima permintaan!\n');
    }
  } else {
    console.log('[Backend] Binary rapih_engine.exe belum terkompilasi; UI akan berjalan dalam Mode Preview.\n');
  }

  // 2. Determine Flutter target (Native Windows vs Chrome Live Bridge)
  const vsReady = hasVisualStudioCpp();
  let targetDevice = 'windows';

  if (forceWeb) {
    targetDevice = 'chrome';
  } else if (!forceWindows && !vsReady) {
    console.log('[Info] Visual Studio C++ Build Tools belum terpasang di Windows ini.');
    console.log('[Info] Menjalankan Flutter UI via Chrome yang terhubung LIVE ke Rust Backend!');
    console.log('[Info] (Jika ingin build .exe Windows native nanti, pasang VS Build Tools lalu jalankan: npm run dev:windows)\n');
    targetDevice = 'chrome';
  }

  // 3. Ensure Flutter dependencies are up to date
  if (!fs.existsSync(path.join(uiDir, '.dart_tool', 'package_config.json'))) {
    console.log('[Frontend] Menjalankan flutter pub get...');
    spawnSync('flutter', ['pub', 'get'], { cwd: uiDir, stdio: 'inherit', shell: true });
  }

  // 4. Launch Flutter UI
  console.log(`[Frontend] Menjalankan Flutter (${targetDevice})...`);
  const flutterArgs = ['run', '-d', targetDevice];
  if (targetDevice === 'chrome') {
    flutterArgs.push('--web-port=8788');
  }

  const flutterProc = spawn('flutter', flutterArgs, {
    cwd: uiDir,
    stdio: 'inherit',
    shell: true,
  });

  const cleanup = () => {
    if (engineProc && !engineProc.killed) {
      engineProc.kill();
    }
    if (flutterProc && !flutterProc.killed) {
      flutterProc.kill();
    }
  };

  process.on('SIGINT', () => {
    cleanup();
    process.exit(0);
  });

  flutterProc.on('exit', (code) => {
    cleanup();
    process.exit(code ?? 0);
  });
}

main();
