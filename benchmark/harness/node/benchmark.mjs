#!/usr/bin/env node
/**
 * Comprehensive TUI Framework Benchmark Harness
 *
 * Measures startup times, memory usage, frame times, and binary sizes
 * for Nocterm and Ink TUI frameworks.
 */

import { spawn, execSync, spawnSync } from 'child_process';
import { existsSync, statSync, writeFileSync, mkdirSync, readFileSync } from 'fs';
import { dirname, join } from 'path';
import { fileURLToPath } from 'url';
import os from 'os';

const __dirname = dirname(fileURLToPath(import.meta.url));
const BENCHMARK_ROOT = join(__dirname, '../..');

// Configuration
const CONFIG = {
  cols: 80,
  rows: 24,
  runsPerTest: 10,
  frameTimeInputs: 50,
  startupTimeout: 5000,
  inputDelay: 20,
};

// Apps to benchmark
const APPS = [
  { name: 'static_layout', dir: '01_static_layout', autoExits: true },
  { name: 'counter', dir: '02_counter', autoExits: false, quitKey: 'q' },
  { name: 'dashboard', dir: '05_dashboard', autoExits: false, quitKey: 'q' },
];

// Statistics helpers
function calcStats(samples) {
  if (!samples.length) return null;
  const sorted = [...samples].sort((a, b) => a - b);
  const n = sorted.length;
  const sum = sorted.reduce((a, b) => a + b, 0);
  const mean = sum / n;
  const variance = sorted.reduce((acc, val) => acc + (val - mean) ** 2, 0) / n;
  const stdDev = Math.sqrt(variance);

  return {
    min: sorted[0],
    max: sorted[n - 1],
    mean: Number(mean.toFixed(3)),
    median: n % 2 ? sorted[Math.floor(n / 2)] : (sorted[n / 2 - 1] + sorted[n / 2]) / 2,
    stdDev: Number(stdDev.toFixed(3)),
    p95: sorted[Math.floor(n * 0.95)] || sorted[n - 1],
    p99: sorted[Math.floor(n * 0.99)] || sorted[n - 1],
    samples: sorted,
  };
}

// Run app with script command for pseudo-tty, capture output and send quit
async function runAppWithScript(command, options = {}) {
  return new Promise((resolve) => {
    let output = '';
    let firstFrameTime = null;

    // Use script -q to run with pseudo-tty
    const child = spawn('/usr/bin/script', ['-q', '/dev/null', '/bin/bash', '-c', command], {
      cwd: options.cwd,
      env: { ...process.env, TERM: 'xterm-256color' },
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    const timeout = setTimeout(() => {
      child.kill('SIGKILL');
    }, options.timeout || CONFIG.startupTimeout);

    child.stdout.on('data', (data) => {
      output += data.toString();
      const match = output.match(/\{"event":"first_frame","timeMs":([\d.]+)\}/);
      if (match && !firstFrameTime) {
        firstFrameTime = parseFloat(match[1]);
        // Send quit key after getting first frame
        if (options.quitKey) {
          setTimeout(() => {
            child.stdin.write(options.quitKey);
            setTimeout(() => child.kill(), 200);
          }, 50);
        }
      }
    });

    child.stderr.on('data', (data) => {
      output += data.toString();
      const match = output.match(/\{"event":"first_frame","timeMs":([\d.]+)\}/);
      if (match && !firstFrameTime) {
        firstFrameTime = parseFloat(match[1]);
        if (options.quitKey) {
          setTimeout(() => {
            child.stdin.write(options.quitKey);
            setTimeout(() => child.kill(), 200);
          }, 50);
        }
      }
    });

    child.on('close', () => {
      clearTimeout(timeout);
      resolve({ firstFrameTime, output });
    });

    child.on('error', () => {
      clearTimeout(timeout);
      resolve({ firstFrameTime: null, output, error: true });
    });
  });
}

// Measure memory using /usr/bin/time -l (macOS)
async function measureMemory(command, cwd) {
  return new Promise((resolve) => {
    let stderr = '';

    const child = spawn('/usr/bin/time', ['-l', '/bin/bash', '-c', command], {
      cwd,
      env: { ...process.env, TERM: 'xterm-256color' },
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    child.stderr.on('data', (data) => {
      stderr += data.toString();
    });

    // Send quit key after a moment for interactive apps
    setTimeout(() => {
      child.stdin.write('q');
    }, 500);

    // Kill after timeout
    const timeout = setTimeout(() => {
      child.kill('SIGKILL');
    }, 3000);

    child.on('close', () => {
      clearTimeout(timeout);

      // Parse macOS time output for peak memory
      const rssMatch = stderr.match(/(\d+)\s+maximum resident set size/);
      const peakRssBytes = rssMatch ? parseInt(rssMatch[1]) : null;

      resolve({
        peakRssMb: peakRssBytes ? peakRssBytes / 1024 / 1024 : null,
        rawOutput: stderr,
      });
    });

    child.on('error', () => {
      clearTimeout(timeout);
      resolve({ peakRssMb: null });
    });
  });
}

// Get binary/artifact sizes
function getBinarySizes(appDir, framework) {
  const result = { methodology: '' };

  if (framework === 'nocterm') {
    const binaryPath = join(appDir, 'app_exe');
    if (existsSync(binaryPath)) {
      const stats = statSync(binaryPath);
      result.binaryBytes = stats.size;
      result.binaryMb = Number((stats.size / 1024 / 1024).toFixed(2));
      result.methodology = 'Dart AOT compiled binary size';

      // Try to get stripped size
      try {
        execSync(`strip -o /tmp/nocterm_stripped "${binaryPath}"`, { stdio: 'pipe' });
        const strippedStats = statSync('/tmp/nocterm_stripped');
        result.strippedBytes = strippedStats.size;
        result.strippedMb = Number((strippedStats.size / 1024 / 1024).toFixed(2));
      } catch (e) {
        // Stripping not available
      }
    }
  } else if (framework === 'ink') {
    const nodeModulesPath = join(appDir, 'node_modules');
    const distPath = join(appDir, 'dist');

    result.methodology = 'node_modules + dist folder sizes';

    if (existsSync(nodeModulesPath)) {
      try {
        const nmSize = execSync(`du -sk "${nodeModulesPath}"`, { encoding: 'utf8' });
        result.nodeModulesKb = parseInt(nmSize.split('\t')[0]);
        result.nodeModulesMb = Number((result.nodeModulesKb / 1024).toFixed(2));
      } catch (e) {}
    }

    if (existsSync(distPath)) {
      try {
        const distSize = execSync(`du -sk "${distPath}"`, { encoding: 'utf8' });
        result.distKb = parseInt(distSize.split('\t')[0]);
      } catch (e) {}
    }

    result.totalMb = result.nodeModulesMb || 0;
  }

  return result;
}

// Run frame time benchmark - send inputs and measure state_change events
async function runFrameTimeBenchmark(command, cwd, numInputs) {
  return new Promise((resolve) => {
    let output = '';
    const stateChangeTimes = [];

    const child = spawn('/usr/bin/script', ['-q', '/dev/null', '/bin/bash', '-c', command], {
      cwd,
      env: { ...process.env, TERM: 'xterm-256color' },
      stdio: ['pipe', 'pipe', 'pipe'],
    });

    const parseOutput = (data) => {
      output += data.toString();
      // Extract all state_change events
      const matches = data.toString().matchAll(/\{"event":"state_change","timeMs":([\d.]+)/g);
      for (const match of matches) {
        stateChangeTimes.push(parseFloat(match[1]));
      }
    };

    child.stdout.on('data', parseOutput);
    child.stderr.on('data', parseOutput);

    // Wait for first_frame then start sending inputs
    let inputsSent = 0;
    const checkAndSendInput = () => {
      if (output.includes('first_frame') && inputsSent < numInputs) {
        child.stdin.write(' '); // space to increment
        inputsSent++;
        setTimeout(checkAndSendInput, CONFIG.inputDelay);
      } else if (inputsSent >= numInputs) {
        setTimeout(() => {
          child.stdin.write('q');
          setTimeout(() => child.kill(), 200);
        }, 100);
      } else {
        setTimeout(checkAndSendInput, 20);
      }
    };

    setTimeout(checkAndSendInput, 200);

    const timeout = setTimeout(() => {
      child.kill('SIGKILL');
    }, 15000);

    child.on('close', () => {
      clearTimeout(timeout);

      // Calculate inter-frame times
      const interFrameTimes = [];
      for (let i = 1; i < stateChangeTimes.length; i++) {
        interFrameTimes.push(stateChangeTimes[i] - stateChangeTimes[i - 1]);
      }

      resolve({ stateChangeTimes, interFrameTimes, inputsSent });
    });

    child.on('error', () => {
      clearTimeout(timeout);
      resolve({ stateChangeTimes: [], interFrameTimes: [], inputsSent: 0 });
    });
  });
}

// Main benchmark runner
async function runBenchmarks() {
  console.log('='.repeat(60));
  console.log('TUI Framework Benchmark Suite');
  console.log('='.repeat(60));
  console.log(`Date: ${new Date().toISOString()}`);
  console.log(`Runs per test: ${CONFIG.runsPerTest}`);
  console.log(`Terminal size: ${CONFIG.cols}x${CONFIG.rows}`);
  console.log('');

  const results = {
    metadata: {
      timestamp: new Date().toISOString(),
      machine: {
        os: os.platform(),
        arch: os.arch(),
        cpuModel: os.cpus()[0]?.model || 'unknown',
        cpuCores: os.cpus().length,
        memoryGb: Number((os.totalmem() / 1024 / 1024 / 1024).toFixed(1)),
        nodeVersion: process.version,
      },
      terminalSize: { cols: CONFIG.cols, rows: CONFIG.rows },
      runsPerTest: CONFIG.runsPerTest,
    },
    startup: {
      methodology: 'Ran each app N times with script -q for pseudo-tty, extracted first_frame event timing from output. Timing measures time from app code start to first frame render complete.',
    },
    binarySize: {
      methodology: 'Nocterm: AOT compiled binary (and stripped). Ink: node_modules folder size.',
    },
    memory: {
      methodology: 'Used /usr/bin/time -l to measure peak RSS (maximum resident set size) on macOS.',
    },
    frameTimes: {
      methodology: `Sent ${CONFIG.frameTimeInputs} keypresses to counter app, measured time between state_change events to get frame-to-frame timing.`,
    },
    apps: {},
  };

  // Get Dart version
  try {
    results.metadata.machine.dartVersion = execSync('dart --version 2>&1', { encoding: 'utf8' }).trim();
  } catch (e) {}

  for (const app of APPS) {
    console.log(`\n${'─'.repeat(60)}`);
    console.log(`Testing: ${app.name}`);
    console.log('─'.repeat(60));

    results.apps[app.name] = { ink: {}, nocterm: {} };

    for (const framework of ['ink', 'nocterm']) {
      const appDir = join(BENCHMARK_ROOT, 'apps', app.dir, framework);

      if (!existsSync(appDir)) {
        console.log(`  ${framework}: SKIPPED (not found)`);
        continue;
      }

      const isNocterm = framework === 'nocterm';
      const command = isNocterm
        ? `./app_exe`
        : `node dist/index.js`;

      console.log(`\n  ${framework}:`);

      // Binary size
      const sizes = getBinarySizes(appDir, framework);
      results.apps[app.name][framework].binarySize = sizes;
      if (isNocterm) {
        console.log(`    Binary: ${sizes.binaryMb}MB (stripped: ${sizes.strippedMb}MB)`);
      } else {
        console.log(`    node_modules: ${sizes.nodeModulesMb}MB`);
      }

      // Startup times
      console.log(`    Running ${CONFIG.runsPerTest} startup tests...`);
      const startupTimes = [];
      for (let i = 0; i < CONFIG.runsPerTest; i++) {
        const result = await runAppWithScript(command, {
          cwd: appDir,
          quitKey: app.quitKey,
          timeout: CONFIG.startupTimeout,
        });
        if (result.firstFrameTime !== null) {
          startupTimes.push(result.firstFrameTime);
          process.stdout.write('.');
        } else {
          process.stdout.write('x');
        }
      }
      console.log('');

      const startupStats = calcStats(startupTimes);
      results.apps[app.name][framework].startup = startupStats;
      if (startupStats) {
        console.log(`    Startup: mean=${startupStats.mean}ms, median=${startupStats.median}ms, stddev=${startupStats.stdDev}ms`);
      }

      // Memory measurement
      console.log(`    Measuring memory...`);
      const memResult = await measureMemory(command, appDir);
      results.apps[app.name][framework].memory = {
        peakRssMb: memResult.peakRssMb ? Number(memResult.peakRssMb.toFixed(2)) : null,
      };
      if (memResult.peakRssMb) {
        console.log(`    Memory (peak RSS): ${memResult.peakRssMb.toFixed(2)}MB`);
      } else {
        console.log(`    Memory: could not measure`);
      }

      // Frame times (only for counter app which supports it)
      if (app.name === 'counter') {
        console.log(`    Running frame time test (${CONFIG.frameTimeInputs} inputs)...`);
        const frameResult = await runFrameTimeBenchmark(command, appDir, CONFIG.frameTimeInputs);
        const frameStats = calcStats(frameResult.interFrameTimes);
        results.apps[app.name][framework].frameTimes = frameStats;
        if (frameStats && frameStats.samples.length > 0) {
          console.log(`    Frame times: mean=${frameStats.mean}ms, p95=${frameStats.p95}ms, p99=${frameStats.p99}ms (${frameStats.samples.length} samples)`);
        } else {
          console.log(`    Frame times: insufficient data`);
        }
      }
    }
  }

  // Summary comparison
  console.log(`\n${'='.repeat(60)}`);
  console.log('SUMMARY COMPARISON');
  console.log('='.repeat(60));

  for (const app of APPS) {
    const appResults = results.apps[app.name];
    if (!appResults.ink?.startup || !appResults.nocterm?.startup) continue;

    const inkStartup = appResults.ink.startup.mean;
    const noctermStartup = appResults.nocterm.startup.mean;
    const startupSpeedup = (inkStartup / noctermStartup).toFixed(1);

    console.log(`\n${app.name}:`);
    console.log(`  Startup: Nocterm ${startupSpeedup}x faster (${noctermStartup}ms vs ${inkStartup}ms)`);

    if (appResults.ink.memory?.peakRssMb && appResults.nocterm.memory?.peakRssMb) {
      const memRatio = (appResults.ink.memory.peakRssMb / appResults.nocterm.memory.peakRssMb).toFixed(1);
      console.log(`  Memory: Nocterm uses ${memRatio}x less (${appResults.nocterm.memory.peakRssMb}MB vs ${appResults.ink.memory.peakRssMb}MB)`);
    }

    if (appResults.ink.binarySize?.nodeModulesMb && appResults.nocterm.binarySize?.binaryMb) {
      const sizeRatio = (appResults.ink.binarySize.nodeModulesMb / appResults.nocterm.binarySize.binaryMb).toFixed(1);
      console.log(`  Binary: Nocterm ${sizeRatio}x smaller (${appResults.nocterm.binarySize.binaryMb}MB vs ${appResults.ink.binarySize.nodeModulesMb}MB)`);
    }
  }

  // Save results
  const outputDir = join(BENCHMARK_ROOT, 'results');
  if (!existsSync(outputDir)) {
    mkdirSync(outputDir, { recursive: true });
  }

  const outputPath = join(outputDir, 'comprehensive_results.json');
  writeFileSync(outputPath, JSON.stringify(results, null, 2));
  console.log(`\nResults saved to: ${outputPath}`);

  return results;
}

// Run if executed directly
runBenchmarks().catch(console.error);
