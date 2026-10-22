// Run separately from node --test. Requires Playwright and a Chromium install.
// CHROMIUM_PATH can point to a local Chromium executable; otherwise Playwright
// uses its bundled browser. The HTTP server shares this process for isolation.
const assert = require('node:assert/strict');
const { mkdir, writeFile } = require('node:fs/promises');
const { resolve } = require('node:path');
const { pathToFileURL } = require('node:url');
const { chromium } = require('playwright');

async function main() {
  const root = resolve(__dirname, '..');
  const port = Number(process.env.AUDIO_TEST_PORT || 5197);
  process.env.PORT = String(port);
  await import(pathToFileURL(resolve(root, 'tools/serve.mjs')).href);
  const browser = await chromium.launch({
    headless: true,
    ...(process.env.CHROMIUM_PATH ? { executablePath: process.env.CHROMIUM_PATH } : {}),
    args: ['--no-sandbox', '--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'],
  });
  try {
    const page = await browser.newPage({ viewport: { width: 1280, height: 800 } });
    const errors = [];
    page.on('pageerror', error => errors.push(error.message));
    await page.goto(`http://127.0.0.1:${port}/?test=1`, { waitUntil: 'networkidle' });
    await page.click('#begin');
    await page.waitForFunction(() => window.__NVS__?.audio.context?.state === 'running');
    await page.keyboard.press('Escape');
    await page.waitForFunction(() => window.__NVS__.paused);
    const result = await page.evaluate(async () => {
      const audio = window.__NVS__.audio;
      const wait = ms => new Promise(resolve => setTimeout(resolve, ms));
      await wait(100);
      const pausedVoiceCount = audio.voices.size;
      const pausedRunning = audio.running;
      const unlocked = await audio.unlock();
      audio.setMuted(false);
      const analyser = audio.context.createAnalyser();
      analyser.fftSize = 8192;
      analyser.smoothingTimeConstant = 0;
      audio.master.connect(analyser);
      const voice = audio.note(69, { duration: 0.35, velocity: 0.7 });
      await wait(180);
      const samples = new Float32Array(analyser.fftSize);
      analyser.getFloatTimeDomainData(samples);
      const rms = Math.sqrt(samples.reduce((sum, value) => sum + value * value, 0) / samples.length);
      const finiteSamples = samples.every(Number.isFinite);
      const spectrum = new Float32Array(analyser.frequencyBinCount);
      analyser.getFloatFrequencyData(spectrum);
      let peakBin = 1;
      for (let i = 2; i < spectrum.length; i += 1) if (spectrum[i] > spectrum[peakBin]) peakBin = i;
      const peakFrequency = peakBin * audio.context.sampleRate / analyser.fftSize;
      await wait(650);
      const naturalReleaseVoiceCount = audio.voices.size;
      audio.playMelody([60, 64, 67, 72], 0.4);
      const scheduledVoiceCount = audio.voices.size;
      audio.stop();
      await wait(120);
      const stopVoiceCount = audio.voices.size;
      const stoppedRunning = audio.running;
      const noteAfterStop = audio.note(69) === null;
      await audio.unlock();
      audio.setMuted(true);
      const mutedNoteRejected = audio.note(60) === null;
      audio.tick(2);
      await wait(100);
      const mutedVoiceCount = audio.voices.size;
      analyser.getFloatTimeDomainData(samples);
      const mutedRms = Math.sqrt(samples.reduce((sum, value) => sum + value * value, 0) / samples.length);
      audio.setMuted(false);
      audio.setRestoration(1);
      for (let i = 0; i < 8; i += 1) audio.tick(0.25);
      const ambientVoiceCount = audio.voices.size;
      audio.stop();
      await wait(120);
      const finalVoiceCount = audio.voices.size;
      analyser.disconnect();
      audio.master.disconnect(analyser);
      return {
        contextState: audio.context.state, sampleRate: audio.context.sampleRate,
        unlocked, scheduledNoteAccepted: Boolean(voice), finiteSamples, rms, peakFrequency,
        pausedVoiceCount, pausedRunning, naturalReleaseVoiceCount, scheduledVoiceCount,
        stopVoiceCount, stoppedRunning, noteAfterStop, mutedNoteRejected,
        mutedVoiceCount, mutedRms, ambientVoiceCount, finalVoiceCount,
      };
    });
    assert.equal(result.unlocked, true, 'AudioContext unlocks after Start');
    assert.equal(result.contextState, 'running');
    assert.equal(result.scheduledNoteAccepted, true);
    assert.equal(result.finiteSamples, true, 'All output samples are finite');
    assert.ok(result.rms > 0.001 && result.rms < 0.5, `Expected audible controlled signal, got RMS ${result.rms}`);
    assert.ok(Math.abs(result.peakFrequency - 440) < 15, `A4 peak is ${result.peakFrequency} Hz`);
    assert.equal(result.pausedVoiceCount, 0, 'Game pause releases voices');
    assert.equal(result.pausedRunning, false, 'Game pause stops ambience');
    assert.equal(result.naturalReleaseVoiceCount, 0, 'Natural note release cleans the graph');
    assert.equal(result.scheduledVoiceCount, 4, 'Melody schedules all four voices');
    assert.equal(result.stopVoiceCount, 0, 'Stop cancels future melody notes');
    assert.equal(result.stoppedRunning, false);
    assert.equal(result.noteAfterStop, true, 'Stopped audio remains silent until unlock');
    assert.equal(result.mutedNoteRejected, true);
    assert.equal(result.mutedVoiceCount, 0, 'Muted notes and ambience create no sources');
    assert.ok(result.mutedRms < 0.00001, 'Muted output is silent');
    assert.ok(result.ambientVoiceCount > 0, 'Restored ambience schedules voices');
    assert.equal(result.finalVoiceCount, 0, 'Ambience releases on stop');
    assert.deepEqual(errors, [], 'No uncaught browser errors');
    const report = {
      status: 'passed', browser: browser.version(),
      verification: 'Actual Chromium Web Audio graph and analyser output. No human listening assessment.',
      checks: result, pageErrors: errors,
    };
    await mkdir(resolve(root, 'docs'), { recursive: true });
    await writeFile(resolve(root, 'docs/audio-verification.json'), JSON.stringify(report, null, 2) + '\n');
    console.log(JSON.stringify(report, null, 2));
  } finally {
    await browser.close();
  }
}

main().then(() => process.exit(0), error => {
  console.error(error);
  process.exit(1);
});
