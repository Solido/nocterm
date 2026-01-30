#!/usr/bin/env node
import React from 'react';
import { render } from 'ink';
import { RapidInput } from './app.js';

// Measurement utilities
const startTime = performance.now();
const latencies: number[] = [];

function logMeasurement(data: Record<string, unknown>): void {
  console.error(JSON.stringify(data));
}

function logMemory(): void {
  const mem = process.memoryUsage();
  logMeasurement({
    event: 'memory',
    heapUsedMb: mem.heapUsed / 1024 / 1024,
    heapTotalMb: mem.heapTotal / 1024 / 1024,
    rssMb: mem.rss / 1024 / 1024,
  });
}

let firstRenderLogged = false;

function handleFirstRender(): void {
  if (firstRenderLogged) return;
  firstRenderLogged = true;

  const firstFrameTime = performance.now() - startTime;
  logMeasurement({
    event: 'first_frame',
    timeMs: firstFrameTime,
  });
  logMemory();
}

function handleKeypress(frameIndex: number, latencyMs: number): void {
  latencies.push(latencyMs);
  logMeasurement({
    event: 'keypress',
    index: frameIndex,
    latencyMs: latencyMs,
  });

  // Log memory every 50 keypresses
  if (frameIndex % 50 === 0) {
    logMemory();
  }
}

// Render the app
const { unmount, waitUntilExit } = render(
  <RapidInput onFirstRender={handleFirstRender} onKeypress={handleKeypress} />
);

// Handle graceful shutdown
function cleanup(): void {
  // Log summary statistics
  if (latencies.length > 0) {
    const avgLatency = latencies.reduce((a, b) => a + b, 0) / latencies.length;
    const minLatency = Math.min(...latencies);
    const maxLatency = Math.max(...latencies);
    const sortedLatencies = [...latencies].sort((a, b) => a - b);
    const p50Index = Math.floor(sortedLatencies.length * 0.5);
    const p95Index = Math.floor(sortedLatencies.length * 0.95);
    const p99Index = Math.floor(sortedLatencies.length * 0.99);

    logMeasurement({
      event: 'summary',
      totalKeypresses: latencies.length,
      avgLatencyMs: avgLatency,
      minLatencyMs: minLatency,
      maxLatencyMs: maxLatency,
      p50LatencyMs: sortedLatencies[p50Index] ?? avgLatency,
      p95LatencyMs: sortedLatencies[p95Index] ?? maxLatency,
      p99LatencyMs: sortedLatencies[p99Index] ?? maxLatency,
      totalTimeMs: performance.now() - startTime,
    });
  }
  logMemory();
}

waitUntilExit().then(() => {
  cleanup();
  process.exit(0);
});

process.on('SIGINT', () => {
  cleanup();
  unmount();
  process.exit(0);
});

process.on('SIGTERM', () => {
  cleanup();
  unmount();
  process.exit(0);
});
