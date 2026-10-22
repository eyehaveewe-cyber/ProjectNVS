/**
 * Project NVS music bus.
 * Adapted from MBean1, branch MBean1-Astra, commit
 * ecd441fe29118995e7036df46ec80fefe8738e9e:
 * reed-audio.js playReed, chip-audio.js chipEnvelope/chipNoise,
 * and audio.js note scheduling/voice cleanup. Source project by eyehaveewe-cyber.
 * This is a local authored pipe/reed synthesizer, with no samples or network calls.
 *
 * await audio.unlock() must run from a user gesture. note() and playMelody()
 * are silent before that. tick(dtSeconds) optionally advances quiet ambience.
 * stop() releases every voice and pauses ambience until unlock() is called again.
 * Call stop() for game pause; hidden documents stop automatically.
 */

const clamp = (value, low, high) => Math.max(low, Math.min(high, value));

// MBean's tick-independent ADSR, retained here so scheduled notes use audio time.
function envelope(gain, when, gate, level, settings) {
  const attack = Math.min(settings.attack, gate * 0.35);
  const decay = Math.min(settings.decay, gate * 0.35);
  const sustain = level * settings.sustain;
  gain.gain.setValueAtTime(0, when);
  gain.gain.linearRampToValueAtTime(level, when + attack);
  gain.gain.linearRampToValueAtTime(sustain, when + attack + decay);
  gain.gain.setValueAtTime(sustain, when + gate);
  gain.gain.linearRampToValueAtTime(0, when + gate + settings.release);
}

// MBean's FNV seed plus xorshift noise. The air texture is reproducible.
function seededNoise(ctx, seconds, id) {
  const buffer = ctx.createBuffer(1, Math.ceil(seconds * ctx.sampleRate), ctx.sampleRate);
  const data = buffer.getChannelData(0);
  let seed = 2166136261;
  for (const character of String(id)) seed = Math.imul(seed ^ character.charCodeAt(0), 16777619);
  for (let i = 0; i < data.length; i += 1) {
    seed ^= seed << 13;
    seed ^= seed >>> 17;
    seed ^= seed << 5;
    data[i] = (seed >>> 0) / 2147483648 - 1;
  }
  return buffer;
}

export class GroveAudio {
  constructor() {
    this.context = null;
    this.master = null;
    this.voices = new Set();
    this.muted = false;
    this.running = false;
    this.restoration = 0;
    this.ambientClock = 0;
    this.ambientStep = 0;
    this.noise = null;
    this.pipeWave = null;
    this.onVisibility = () => {
      if (globalThis.document?.hidden) this.stop();
    };
    globalThis.document?.addEventListener('visibilitychange', this.onVisibility);
  }

  async unlock() {
    const AudioContextClass = globalThis.AudioContext || globalThis.webkitAudioContext;
    if (!AudioContextClass) return false;
    try {
      if (!this.context || this.context.state === 'closed') {
        this.context = new AudioContextClass({ latencyHint: 'interactive' });
        this.master = this.context.createGain();
        this.master.gain.value = this.muted ? 0 : 0.62;
        this.master.connect(this.context.destination);
        this.noise = seededNoise(this.context, 1, 'nvs-mbean-pipe-air');
        const real = new Float32Array(17);
        const imaginary = new Float32Array(17);
        // MBean's periodic reed harmonics, softened for the faun's wooden pipes.
        for (let harmonic = 1; harmonic < imaginary.length; harmonic += 1) {
          imaginary[harmonic] = (harmonic % 2 ? 1 : 0.22) / harmonic ** 2.15;
        }
        this.pipeWave = this.context.createPeriodicWave(real, imaginary);
      }
      if (this.context.state === 'suspended') await this.context.resume();
      this.running = this.context.state === 'running';
      return this.running;
    } catch {
      this.running = false;
      return false;
    }
  }

  /** Schedule a MIDI pitch. `when` is absolute AudioContext time in seconds. */
  note(midi, { duration = 0.45, velocity = 0.7, voice = 'pipes', when } = {}) {
    const ctx = this.context;
    if (!this.running || this.muted || ctx?.state !== 'running' || !Number.isFinite(midi)) return null;
    if (globalThis.document?.hidden) return null;
    if (this.voices.size >= 48) return null;
    const gate = clamp(Number.isFinite(duration) ? duration : 0.45, 0.04, 8);
    const strength = clamp(Number.isFinite(velocity) ? velocity : 0.7, 0, 1);
    if (!strength) return null;
    const onset = Math.max(ctx.currentTime + 0.004, Number.isFinite(when) ? when : ctx.currentTime);
    const frequency = 440 * 2 ** ((clamp(midi, 24, 108) - 69) / 12);
    const ambient = voice === 'ambient';
    const bass = voice === 'bass';
    const settings = {
      attack: ambient ? 0.22 : bass ? 0.04 : 0.035,
      decay: 0.09,
      sustain: ambient ? 0.6 : 0.76,
      release: ambient ? 0.6 : 0.2,
    };
    const level = strength * (ambient ? 0.045 : bass ? 0.07 : 0.17);
    const body = ctx.createOscillator();
    const filter = ctx.createBiquadFilter();
    const bodyGain = ctx.createGain();
    const bus = ctx.createGain();
    const lfo = ctx.createOscillator();
    const depth = ctx.createGain();
    const air = ctx.createBufferSource();
    const airFilter = ctx.createBiquadFilter();
    const airGain = ctx.createGain();
    const sources = [body, lfo, air];
    const nodes = [body, filter, bodyGain, bus, lfo, depth, air, airFilter, airGain];
    if (ambient || bass) body.type = 'sine';
    else body.setPeriodicWave(this.pipeWave);
    body.frequency.value = frequency;
    filter.type = 'lowpass';
    filter.frequency.value = Math.min(ctx.sampleRate * 0.4, ambient ? 1200 : frequency * 4.8);
    filter.Q.value = 0.6;
    envelope(bodyGain, onset, gate, level, settings);
    body.connect(filter);
    filter.connect(bodyGain);
    bodyGain.connect(bus);
    bus.connect(this.master);

    // Quiet delayed breath vibrato, adapted from playReed's detune modulation.
    lfo.frequency.value = 4.7;
    depth.gain.setValueAtTime(0, onset);
    depth.gain.linearRampToValueAtTime(ambient || bass ? 1 : 7, onset + Math.min(0.18, gate));
    lfo.connect(depth);
    depth.connect(body.detune);
    air.buffer = this.noise;
    air.loop = true;
    airFilter.type = 'bandpass';
    airFilter.frequency.value = Math.min(2200, ctx.sampleRate * 0.3);
    airFilter.Q.value = 0.5;
    envelope(airGain, onset, gate, level * (ambient || bass ? 0 : 0.045), settings);
    air.connect(airFilter);
    airFilter.connect(airGain);
    airGain.connect(bus);

    let finished = false;
    const handle = {
      stop: () => {
        if (finished) return;
        const now = ctx.currentTime;
        bus.gain.cancelScheduledValues(now);
        bus.gain.setValueAtTime(bus.gain.value, now);
        bus.gain.linearRampToValueAtTime(0, now + 0.025);
        for (const source of sources) {
          try { source.stop(now + 0.03); } catch { /* It has already ended. */ }
        }
      },
    };
    const cleanup = () => {
      if (finished) return;
      finished = true;
      this.voices.delete(handle);
      for (const node of nodes) node.disconnect();
    };
    body.onended = cleanup;
    const end = onset + gate + settings.release + 0.025;
    for (const source of sources) {
      source.start(onset);
      source.stop(end);
    }
    this.voices.add(handle);
    return handle;
  }

  /** Schedule an array of MIDI pitches at a fixed beat; null entries are rests. */
  playMelody(pitches, beat = 0.4) {
    if (!this.running || !Array.isArray(pitches)) return [];
    const spacing = clamp(Number.isFinite(beat) ? beat : 0.4, 0.08, 2);
    const start = this.context.currentTime + 0.03;
    return pitches.slice(0, 64).map((pitch, index) => pitch == null ? null : this.note(pitch, {
      duration: spacing * 0.82,
      velocity: 0.62,
      when: start + index * spacing,
    })).filter(Boolean);
  }

  setRestoration(fraction) {
    this.restoration = Number.isFinite(fraction) ? clamp(fraction, 0, 1) : 0;
  }

  setMuted(boolean) {
    this.muted = Boolean(boolean);
    if (this.master) this.master.gain.setTargetAtTime(this.muted ? 0 : 0.62, this.context.currentTime, 0.025);
    if (this.muted) for (const handle of this.voices) handle.stop();
  }

  /** Optional ambience clock. Pass elapsed seconds from the game's frame loop. */
  tick(dt) {
    if (!this.running || this.muted || !Number.isFinite(dt) || dt <= 0) return;
    if (globalThis.document?.hidden) { this.stop(); return; }
    this.ambientClock += Math.min(dt, 0.25);
    const spacing = 1.4 - this.restoration * 0.45;
    if (this.ambientClock < spacing) return;
    this.ambientClock %= spacing;
    const phrase = this.restoration < 0.34 ? [50, 57, 53, 60, 57, 53, 62, 57] : [50, 57, 62, 64, 69, 64, 62, 57];
    const step = this.ambientStep++;
    // Increasing restoration brings in upper voices without increasing loudness.
    this.note(phrase[step % phrase.length] + (this.restoration > 0.7 ? 12 : 0), {
      voice: 'ambient', duration: spacing * 1.7, velocity: 0.48,
    });
    if (step % 4 === 0) this.note(step % 8 === 0 ? 38 : 43, {
      voice: 'bass', duration: spacing * 3.1, velocity: 0.22,
    });
  }

  stop() {
    this.running = false;
    this.ambientClock = 0;
    for (const handle of this.voices) handle.stop();
  }
}
