#!/usr/bin/env node
import React from 'react';
import { render } from 'ink';
import { ScrollingList } from './app.js';

// Measurement utilities
const startTime = performance.now();
const frameTimes: number[] = [];

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

function handleFrame(frameIndex: number, frameTime: number): void {
  frameTimes.push(frameTime);
  logMeasurement({
    event: 'frame',
    index: frameIndex,
    timeMs: frameTime,
  });

  // Log memory every 20 frames
  if (frameIndex % 20 === 0) {
    logMemory();
  }
}

// Render the app
const { unmount, waitUntilExit } = render(
  <ScrollingList onFirstRender={handleFirstRender} onFrame={handleFrame} />
);

// Handle graceful shutdown
function cleanup(): void {
  // Log summary statistics
  if (frameTimes.length > 0) {
    const avgFrameTime = frameTimes.reduce((a, b) => a + b, 0) / frameTimes.length;
    const minFrameTime = Math.min(...frameTimes);
    const maxFrameTime = Math.max(...frameTimes);
    const sortedTimes = [...frameTimes].sort((a, b) => a - b);
    const p95Index = Math.floor(sortedTimes.length * 0.95);
    const p95FrameTime = sortedTimes[p95Index] ?? maxFrameTime;

    logMeasurement({
      event: 'summary',
      totalFrames: frameTimes.length,
      avgFrameTimeMs: avgFrameTime,
      minFrameTimeMs: minFrameTime,
      maxFrameTimeMs: maxFrameTime,
      p95FrameTimeMs: p95FrameTime,
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
