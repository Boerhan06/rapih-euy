import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import os from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const rootDir = path.resolve(__dirname, '..');
const engineDir = path.join(rootDir, 'rapih_engine');
const userHome = os.homedir();

function resolveCargo() {
  const localCargo = path.join(userHome, '.cargo', 'bin', 'cargo.exe');
  if (fs.existsSync(localCargo)) return localCargo;
  return 'cargo';
}

function resolveRustup() {
  const localRustup = path.join(userHome, '.cargo', 'bin', 'rustup.exe');
  if (fs.existsSync(localRustup)) return localRustup;
  return 'rustup';
}

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

function find64BitMingwBin() {
  const candidates = [
    'D:\\WinLibs\\mingw64\\bin',
    'D:\\WinLibs\\bin',
    'C:\\WinLibs\\mingw64\\bin',
    'C:\\mingw64\\bin',
    'D:\\mingw64\\bin',
  ];

  // Also scan WinGet portable packages directory if installed there
  const localAppData = process.env.LOCALAPPDATA;
  if (localAppData) {
    const wingetPkgDir = path.join(localAppData, 'Microsoft', 'WinGet', 'Packages');
    if (fs.existsSync(wingetPkgDir)) {
      for (const entry of fs.readdirSync(wingetPkgDir)) {
        if (entry.toLowerCase().includes('winlibs')) {
          candidates.push(path.join(wingetPkgDir, entry, 'mingw64', 'bin'));
        }
      }
    }
  }

  return candidates.find(
    (dir) => fs.existsSync(path.join(dir, 'gcc.exe')) && fs.existsSync(path.join(dir, 'as.exe'))
  ) || null;
}

function getInstalledToolchains(rustup) {
  const res = spawnSync(rustup, ['toolchain', 'list'], { encoding: 'utf8' });
  if (res.status !== 0) return [];
  return res.stdout.split(/\r?\n/).map((s) => s.trim()).filter(Boolean);
}

export function getEngineBinaryPath() {
  const candidates = [
    path.join(engineDir, 'target', 'release', 'rapih_engine.exe'),
    path.join(engineDir, 'target', 'debug', 'rapih_engine.exe'),
    path.join(engineDir, 'target', 'x86_64-pc-windows-gnu', 'release', 'rapih_engine.exe'),
    path.join(engineDir, 'target', 'x86_64-pc-windows-gnu', 'debug', 'rapih_engine.exe'),
  ];
  return candidates.find((p) => fs.existsSync(p)) || null;
}

export function buildEngine() {
  const cargo = resolveCargo();
  const rustup = resolveRustup();
  const toolchains = getInstalledToolchains(rustup);
  const hasMsvc = hasVisualStudioCpp();
  const gnuToolchain = toolchains.find((t) => t.includes('x86_64-pc-windows-gnu'));
  const mingw64Bin = find64BitMingwBin();

  const env = { ...process.env };
  let args = ['build', '--release'];

  if (!hasMsvc && gnuToolchain && mingw64Bin) {
    console.log(`[Rapih Euy] Menggunakan Rust GNU + 64-bit WinLibs (${mingw64Bin})...`);
    args = ['+stable-x86_64-pc-windows-gnu', 'build', '--release'];
    // Put 64-bit WinLibs FIRST so 32-bit C:\MinGW\bin does not interfere
    env.PATH = `${mingw64Bin};${env.PATH || ''}`;
  } else if (!hasMsvc && gnuToolchain) {
    console.log('[Rapih Euy] Menggunakan Rust GNU toolchain...');
    args = ['+stable-x86_64-pc-windows-gnu', 'build', '--release'];
  } else if (!hasMsvc) {
    console.warn('[Rapih Euy] MSVC Linker & GNU toolchain belum siap.');
    return null;
  }

  console.log('[Rapih Euy] Mengompilasi rapih_engine (Rust)...');
  const res = spawnSync(cargo, args, {
    cwd: engineDir,
    stdio: 'inherit',
    env,
  });

  if (res.status !== 0) {
    return null;
  }

  return getEngineBinaryPath();
}

const isMain = process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url);
if (isMain) {
  const bin = buildEngine();
  if (!bin) {
    process.exit(1);
  }
  console.log(`[Rapih Euy] Engine berhasil dikompilasi: ${bin}`);
}
