#!/usr/bin/env node
import React from 'react';
import { render } from 'ink';
import { StaticLayout } from './app.js';

// Measurement utilities
const startTime = performance.now();

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

  // For static layout, we exit after a short delay to allow measurements
  setTimeout(() => {
    logMeasurement({
      event: 'complete',
      totalTimeMs: performance.now() - startTime,
    });
    logMemory();
    process.exit(0);
  }, 100);
}

// Render the app
const { unmount } = render(<StaticLayout onFirstRender={handleFirstRender} />);

// Handle graceful shutdown
process.on('SIGINT', () => {
  unmount();
  process.exit(0);
});

process.on('SIGTERM', () => {
  unmount();
  process.exit(0);
});
