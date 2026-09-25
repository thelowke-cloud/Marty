/* Note Reader — web version. Vanilla JS, no dependencies. */
(function () {
  'use strict';

  // ───────────────────────── Music model ─────────────────────────
  // Letters in Czech naming: c d e f g a h (h instead of b).
  const LETTERS = ['c', 'd', 'e', 'f', 'g', 'a', 'h'];
  const SEMITONES = [0, 2, 4, 5, 7, 9, 11];
  const HAS_BLACK_ABOVE = [true, true, false, true, true, true, false];

  const Note = {
    make: (letter, octave) => ({ letter, octave }),
    fromDiatonic: (i) => ({ letter: ((i % 7) + 7) % 7, octave: Math.floor(i / 7) }),
    diatonic: (n) => n.octave * 7 + n.letter,
    id: (n) => LETTERS[n.letter].toUpperCase() + n.octave,
    midi: (n) => (n.octave + 1) * 12 + SEMITONES[n.letter],
    freq: (n) => 440 * Math.pow(2, (Note.midi(n) - 69) / 12),
    eq: (a, b) => !!a && !!b && a.letter === b.letter && a.octave === b.octave,
    // Czech octave-aware name: C (velká), c (malá), c1 (jednočárková), c2 …
    czech(n) {
      const l = LETTERS[n.letter];
      if (n.octave < 2) return l.toUpperCase() + (2 - n.octave);
      if (n.octave === 2) return l.toUpperCase();
      if (n.octave === 3) return l;
      return l + (n.octave - 3);
    },
    range(lo, hi) {
      const out = [];
      for (let i = Note.diatonic(lo); i <= Note.diatonic(hi); i++) out.push(Note.fromDiatonic(i));
      return out;
    }
  };

  // Staff steps: 0 = bottom line, 1 = first space, … 8 = top line.
  // Treble bottom line = e1 (E4). Bass bottom line = G (G2).
  // Full table: see NoteReader/Models/Clef.swift in the repo.
  const CLEFS = {
    treble: { title: 'Treble', bottom: Note.make(2, 4) },
    bass: { title: 'Bass', bottom: Note.make(4, 2) }
  };
  const staffStep = (clef, n) => Note.diatonic(n) - Note.diatonic(CLEFS[clef].bottom);
  function ledgerSteps(step) {
    const out = [];
    if (step < 0) for (let s = -2; s >= step; s -= 2) out.push(s);
    else if (step > 8) for (let s = 10; s <= step; s += 2) out.push(s);
    return out;
  }

  // Beginner: treble c1–g2, bass F–c1 (only the c1 ledger line).
  // Intermediate: treble a–c3, bass C–e1 (two ledger lines each way).
  const RANGES = {
    beginner: { title: 'Beginner', treble: [Note.make(0, 4), Note.make(4, 5)], bass: [Note.make(3, 2), Note.make(0, 4)] },
    intermediate: { title: 'Intermediate', treble: [Note.make(5, 3), Note.make(0, 6)], bass: [Note.make(0, 2), Note.make(2, 4)] }
  };
  const rangeNotes = (preset, clef) => Note.range(RANGES[preset][clef][0], RANGES[preset][clef][1]);
  const rangeSummary = (preset, clef) => Note.czech(RANGES[preset][clef][0]) + '–' + Note.czech(RANGES[preset][clef][1]);

  const CLEF_CHOICES = { treble: { title: 'Treble', clefs: ['treble'] }, bass: { title: 'Bass', clefs: ['bass'] }, both: { title: 'Both', clefs: ['treble', 'bass'] } };
  const ANSWER_MODES = { letters: { title: 'Letters' }, piano: { title: 'Piano' } };
  const MODES = {
    practice: { title: 'Practice', sub: 'Endless. Accuracy and average time.' },
    sprint: { title: 'Sprint', sub: '60 seconds. +1 correct, −1 wrong.' },
    streak: { title: 'Streak', sub: 'How many in a row before a slip?' }
  };
  const promptKey = (p) => p.clef + ':' + Note.id(p.note);
  const promptEq = (a, b) => !!a && !!b && a.clef === b.clef && Note.eq(a.note, b.note);
  function parsePromptKey(key) {
    const m = /^(treble|bass):([CDEFGAH])(-?\d+)$/.exec(key);
    if (!m) return null;
    return { clef: m[1], note: Note.make(LETTERS.indexOf(m[2].toLowerCase()), parseInt(m[3], 10)) };
  }

  // ───────────────────────── Storage ─────────────────────────
  const storage = {
    get(key, fallback) {
      try {
        const raw = localStorage.getItem(key);
        return raw ? JSON.parse(raw) : fallback;
      } catch (e) { return fallback; }
    },
    set(key, value) {
      try { localStorage.setItem(key, JSON.stringify(value)); } catch (e) { /* private mode etc. */ }
    }
  };

  const SETTINGS_KEY = 'notereader.settings.v1';
  const settings = Object.assign(
    { clefChoice: 'treble', range: 'beginner', answerMode: 'letters', pianoLabels: true, soundOn: true, hapticsOn: true, installHintDismissed: false },
    storage.get(SETTINGS_KEY, {})
  );
  if (!CLEF_CHOICES[settings.clefChoice]) settings.clefChoice = 'treble';
  if (!RANGES[settings.range]) settings.range = 'beginner';
  if (!ANSWER_MODES[settings.answerMode]) settings.answerMode = 'letters';
  const saveSettings = () => storage.set(SETTINGS_KEY, settings);

  const STATS_KEY = 'notereader.stats.v1';
  const stats = {
    data: Object.assign({ notes: {}, sprintBests: {}, streakBests: {}, weights: {} }, storage.get(STATS_KEY, {})),
    save() { storage.set(STATS_KEY, this.data); },
    bestKey: (clefChoice, range) => clefChoice + '-' + range,
    get(prompt) { return this.data.notes[promptKey(prompt)] || null; },
    record(prompt, correct, ms) {
      const k = promptKey(prompt);
      const e = this.data.notes[k] || { attempts: 0, correct: 0, totalMs: 0 };
      e.attempts += 1;
      if (correct) e.correct += 1;
      e.totalMs += Math.max(0, ms);
      this.data.notes[k] = e;
      this.save();
    },
    saveWeights(w) { this.data.weights = w; this.save(); },
    sprintBest(c, r) { const v = this.data.sprintBests[this.bestKey(c, r)]; return typeof v === 'number' ? v : null; },
    streakBest(c, r) { const v = this.data.streakBests[this.bestKey(c, r)]; return typeof v === 'number' ? v : null; },
    submitSprint(score, c, r) {
      const k = this.bestKey(c, r); const prev = this.data.sprintBests[k];
      if (typeof prev !== 'number' || score > prev) { this.data.sprintBests[k] = score; this.save(); return true; }
      return false;
    },
    submitStreak(streak, c, r) {
      const k = this.bestKey(c, r); const prev = this.data.streakBests[k] || 0;
      if (streak > prev) { this.data.streakBests[k] = streak; this.save(); return true; }
      return false;
    },
    reset() { this.data = { notes: {}, sprintBests: {}, streakBests: {}, weights: {} }; this.save(); },
    totals() {
      let attempts = 0, correct = 0;
      Object.values(this.data.notes).forEach((e) => { attempts += e.attempts; correct += e.correct; });
      return { attempts, correct, accuracy: attempts ? correct / attempts : 0, seen: Object.keys(this.data.notes).length };
    }
  };
  const accuracyOf = (e) => (e && e.attempts ? e.correct / e.attempts : 0);
  const averageOf = (e) => (e && e.attempts ? Math.round(e.totalMs / e.attempts) : 0);

  // ───────────────────────── Audio ─────────────────────────
  const synth = {
    ctx: null,
    unlock() {
      const AC = window.AudioContext || window.webkitAudioContext;
      if (!AC) return;
      if (!this.ctx) this.ctx = new AC();
      if (this.ctx.state === 'suspended') this.ctx.resume().catch(() => {});
    },
    play(note) {
      this.unlock();
      const ctx = this.ctx;
      if (!ctx) return;
      const t = ctx.currentTime;
      const freq = Note.freq(note);
      const gain = ctx.createGain();
      gain.gain.setValueAtTime(0.0001, t);
      gain.gain.linearRampToValueAtTime(0.28, t + 0.012);
      gain.gain.exponentialRampToValueAtTime(0.0001, t + 0.75);
      gain.connect(ctx.destination);
      const sine = ctx.createOscillator(); sine.type = 'sine'; sine.frequency.value = freq;
      const tri = ctx.createOscillator(); tri.type = 'triangle'; tri.frequency.value = freq;
      const sineGain = ctx.createGain(); sineGain.gain.value = 0.72;
      const triGain = ctx.createGain(); triGain.gain.value = 0.28;
      sine.connect(sineGain).connect(gain);
      tri.connect(triGain).connect(gain);
      sine.start(t); tri.start(t);
      sine.stop(t + 0.8); tri.stop(t + 0.8);
    }
  };

  const haptics = {
    light() { if (navigator.vibrate) navigator.vibrate(10); },
    error() { if (navigator.vibrate) navigator.vibrate([30, 40, 30]); }
  };

  // ───────────────────────── Note picker ─────────────────────────
  const MIN_W = 1, MAX_W = 3, RETRY_GAP = 2;
  class NotePicker {
    constructor(weights) {
      this.weights = {};
      Object.keys(weights || {}).forEach((k) => { this.weights[k] = Math.min(MAX_W, Math.max(MIN_W, weights[k] | 0)); });
      this.last = null;
      this.queue = [];
      this.index = 0;
    }
    effectiveWeight(p) {
      let w = this.weights[promptKey(p)] || MIN_W;
      const s = stats.get(p);
      if (s && s.attempts >= 2) {
        w += (1 - accuracyOf(s)) * 2;
        if (averageOf(s) > 2500) w += 1;
      }
      return Math.max(w, 0.1);
    }
    next(pool) {
      if (!pool.length) return null;
      this.index += 1;
      const due = this.queue.findIndex((r) => r.due <= this.index && !promptEq(r.prompt, this.last));
      if (due >= 0) {
        const r = this.queue.splice(due, 1)[0];
        this.last = r.prompt;
        return { prompt: r.prompt, isRetry: true };
      }
      let candidates = pool.filter((p) => !promptEq(p, this.last));
      if (!candidates.length) candidates = pool;
      const weights = candidates.map((p) => this.effectiveWeight(p));
      const total = weights.reduce((a, b) => a + b, 0);
      let roll = Math.random() * total;
      let chosen = candidates[0];
      for (let i = 0; i < candidates.length; i++) {
        if (roll < weights[i]) { chosen = candidates[i]; break; }
        roll -= weights[i];
      }
      this.queue = this.queue.filter((r) => !promptEq(r.prompt, chosen));
      this.last = chosen;
      return { prompt: chosen, isRetry: false };
    }
    miss(p) {
      const k = promptKey(p);
      this.weights[k] = Math.min(MAX_W, (this.weights[k] || MIN_W) + 1);
      this.queue = this.queue.filter((r) => !promptEq(r.prompt, p));
      this.queue.push({ prompt: p, due: this.index + RETRY_GAP + 1 });
    }
    hit(p) {
      const k = promptKey(p);
      this.weights[k] = Math.max(MIN_W, (this.weights[k] || MIN_W) - 1);
    }
  }

  // ───────────────────────── Game session ─────────────────────────
  const SPRINT_SECONDS = 60, CORRECT_DELAY = 450, WRONG_DELAY = 1300;
  class GameSession {
    constructor(mode, onChange) {
      this.mode = mode;
      this.onChange = onChange;
      this.clefChoice = settings.clefChoice;
      this.range = settings.range;
      this.pool = [];
      CLEF_CHOICES[this.clefChoice].clefs.forEach((clef) => {
        rangeNotes(this.range, clef).forEach((note) => this.pool.push({ clef, note }));
      });
      this.picker = new NotePicker(stats.data.weights);
      const first = this.picker.next(this.pool) || { prompt: { clef: 'treble', note: Note.make(0, 4) }, isRetry: false };
      this.prompt = first.prompt;
      this.isRetry = first.isRetry;
      this.phase = 'playing';
      this.feedback = null;
      this.correct = 0; this.wrong = 0; this.score = 0;
      this.streak = 0; this.bestStreak = 0;
      this.totalMs = 0; this.lastMs = null;
      this.timeRemaining = SPRINT_SECONDS;
      this.isNewBest = false; this.personalBest = null;
      this.timer = null; this.advanceTimer = null; this.started = false;
    }
    get attempts() { return this.correct + this.wrong; }
    get accuracy() { return this.attempts ? this.correct / this.attempts : 0; }
    get averageMs() { return this.attempts ? Math.round(this.totalMs / this.attempts) : 0; }
    get answerNotes() { return rangeNotes(this.range, this.prompt.clef); }
    start() {
      if (this.started) return;
      this.started = true;
      this.shownAt = performance.now();
      if (this.mode === 'sprint') {
        this.end = Date.now() + SPRINT_SECONDS * 1000;
        this.timer = setInterval(() => this.tick(), 50);
      }
    }
    stop() {
      clearInterval(this.timer); this.timer = null;
      clearTimeout(this.advanceTimer); this.advanceTimer = null;
      stats.saveWeights(this.picker.weights);
      if (this.mode === 'streak' && this.phase !== 'finished') stats.submitStreak(this.bestStreak, this.clefChoice, this.range);
    }
    answer(note) {
      if (this.phase !== 'playing') return;
      const ms = Math.round(performance.now() - this.shownAt);
      const correct = Note.eq(note, this.prompt.note);
      const current = this.prompt;
      stats.record(current, correct, ms);
      this.totalMs += ms; this.lastMs = ms;
      if (correct) {
        this.correct += 1; this.streak += 1; this.bestStreak = Math.max(this.bestStreak, this.streak); this.score += 1;
        this.picker.hit(current);
      } else {
        this.wrong += 1; this.streak = 0; this.score -= 1;
        this.picker.miss(current);
      }
      stats.saveWeights(this.picker.weights);
      this.feedback = { correct, answered: note, expected: current, ms };
      this.phase = 'feedback';
      if (settings.soundOn) synth.play(current.note);
      if (settings.hapticsOn) (correct ? haptics.light() : haptics.error());
      this.advanceTimer = setTimeout(() => {
        if (this.mode === 'streak' && !correct) this.finish(); else this.advance();
      }, correct ? CORRECT_DELAY : WRONG_DELAY);
      this.onChange();
    }
    advance() {
      if (this.phase !== 'feedback') return;
      const pick = this.picker.next(this.pool);
      if (pick) { this.prompt = pick.prompt; this.isRetry = pick.isRetry; }
      this.feedback = null;
      this.phase = 'playing';
      this.shownAt = performance.now();
      this.onChange();
    }
    tick() {
      if (this.phase === 'finished') return;
      const remaining = Math.max(0, (this.end - Date.now()) / 1000);
      const changed = Math.ceil(remaining) !== Math.ceil(this.timeRemaining);
      this.timeRemaining = remaining;
      if (remaining <= 0) this.finish();
      else if (changed) this.onChange();
    }
    finish() {
      if (this.phase === 'finished') return;
      clearInterval(this.timer); this.timer = null;
      clearTimeout(this.advanceTimer); this.advanceTimer = null;
      this.phase = 'finished';
      stats.saveWeights(this.picker.weights);
      if (this.mode === 'sprint') {
        this.isNewBest = stats.submitSprint(this.score, this.clefChoice, this.range);
        this.personalBest = stats.sprintBest(this.clefChoice, this.range);
      } else if (this.mode === 'streak') {
        this.isNewBest = stats.submitStreak(this.bestStreak, this.clefChoice, this.range);
        this.personalBest = stats.streakBest(this.clefChoice, this.range);
      }
      this.onChange();
    }
  }

  // ───────────────────────── Formatting ─────────────────────────
  const fmt = {
    seconds: (ms) => (ms / 1000).toFixed(1) + ' s',
    percent: (v) => Math.round(v * 100) + '%',
    clock: (s) => { const w = Math.ceil(s); return Math.floor(w / 60) + ':' + String(w % 60).padStart(2, '0'); }
  };
  const esc = (s) => String(s).replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

  // ───────────────────────── Staff (SVG) ─────────────────────────
  function staffSVG(clef, note, height) {
    const W = 340, H = height || 220;
    const space = Math.min(H / 11, 26);
    const bottomY = H / 2 + 2 * space;
    const left = space * 0.6, right = W - space * 0.6;
    const lw = Math.max(1, space * 0.075).toFixed(2);
    const y = (step) => bottomY - step * space / 2;
    const f = (v) => v.toFixed(2);
    let out = `<svg class="staff" viewBox="0 0 ${W} ${H}" xmlns="http://www.w3.org/2000/svg" role="img" aria-label="${clef} clef${note ? ', note ' + Note.czech(note) : ''}">`;
    // staff lines
    let d = '';
    for (let i = 0; i < 5; i++) { const yy = bottomY - i * space; d += `M${f(left)} ${f(yy)}H${f(right)}`; }
    out += `<path d="${d}" stroke="currentColor" stroke-width="${lw}" fill="none"/>`;
    // clef
    const clefX = left + space * 1.9;
    const sw = Math.max(1.5, space * 0.2).toFixed(2);
    if (clef === 'treble') {
      const p = (u, v) => f(clefX + u * space) + ' ' + f(bottomY - v * space);
      const path = `M${p(-0.15, -1.05)}C${p(-0.25, -1.55)} ${p(0.25, -1.7)} ${p(0.5, -1.45)}` +
        `C${p(0.8, -1.3)} ${p(0.92, -0.95)} ${p(0.75, -0.6)}` +
        `C${p(0.6, 1.5)} ${p(1.05, 4.2)} ${p(0.55, 5.9)}` +
        `C${p(0.35, 6.75)} ${p(-0.05, 5.55)} ${p(-0.05, 4.05)}` +
        `C${p(-0.05, 3.15)} ${p(0.75, 2.75)} ${p(1.0, 2.15)}` +
        `C${p(1.25, 1.55)} ${p(1.05, 0.15)} ${p(0.25, 0.1)}` +
        `C${p(-0.45, 0.05)} ${p(-0.88, 0.6)} ${p(-0.78, 1.15)}` +
        `C${p(-0.72, 1.8)} ${p(-0.3, 2.1)} ${p(0.2, 2.02)}` +
        `C${p(0.75, 1.95)} ${p(0.85, 1.4)} ${p(0.55, 1.2)}` +
        `C${p(0.4, 1.02)} ${p(0.25, 0.94)} ${p(0.12, 0.98)}`;
      out += `<path d="${path}" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>`;
      out += `<circle cx="${f(clefX - 0.15 * space)}" cy="${f(bottomY + 1.05 * space)}" r="${f(space * 0.22)}" fill="currentColor"/>`;
    } else {
      const p = (u, v) => f(clefX + (u - 0.4) * space) + ' ' + f(bottomY - v * space);
      const path = `M${p(0.05, 3.0)}C${p(0.05, 3.6)} ${p(0.25, 4.05)} ${p(0.6, 4.05)}` +
        `C${p(1.05, 4.05)} ${p(1.3, 3.55)} ${p(1.3, 3.0)}` +
        `C${p(1.3, 1.6)} ${p(0.55, 0.7)} ${p(-0.2, 0.15)}`;
      out += `<path d="${path}" stroke="currentColor" stroke-width="${sw}" stroke-linecap="round" stroke-linejoin="round" fill="none"/>`;
      const c = (u, v, r) => `<circle cx="${f(clefX + (u - 0.4) * space)}" cy="${f(bottomY - v * space)}" r="${f(r)}" fill="currentColor"/>`;
      out += c(0.15, 3.0, space * 0.3) + c(1.75, 3.5, space * 0.16) + c(1.75, 2.5, space * 0.16);
    }
    // note
    if (note) {
      const step = staffStep(clef, note);
      const nx = left + (right - left) * 0.64;
      const ny = y(step);
      let ld = '';
      ledgerSteps(step).forEach((s) => { ld += `M${f(nx - space * 1.15)} ${f(y(s))}H${f(nx + space * 1.15)}`; });
      if (ld) out += `<path d="${ld}" stroke="currentColor" stroke-width="${(lw * 1.15).toFixed(2)}" fill="none"/>`;
      const rx = space * 0.775, ry = space * 0.51;      // outer
      const irx = space * 0.43, iry = space * 0.31;     // inner, tilted
      const rot = -31.5, cs = Math.cos(rot * Math.PI / 180), sn = Math.sin(rot * Math.PI / 180);
      const head =
        `M${f(nx - rx)} ${f(ny)}a${f(rx)} ${f(ry)} 0 1 0 ${f(2 * rx)} 0a${f(rx)} ${f(ry)} 0 1 0 ${f(-2 * rx)} 0Z` +
        `M${f(nx + irx * cs)} ${f(ny + irx * sn)}a${f(irx)} ${f(iry)} ${rot} 1 0 ${f(-2 * irx * cs)} ${f(-2 * irx * sn)}a${f(irx)} ${f(iry)} ${rot} 1 0 ${f(2 * irx * cs)} ${f(2 * irx * sn)}Z`;
      out += `<path d="${head}" fill="currentColor" fill-rule="evenodd"/>`;
    }
    return out + '</svg>';
  }

  // ───────────────────────── Rendering ─────────────────────────
  const app = document.getElementById('app');
  const state = { screen: 'home', session: null };

  const ICONS = {
    practice: '<svg viewBox="0 0 24 24"><path d="M18.6 6.6c-2.1 0-3.5 1.3-4.6 2.7 1 1.3 2.1 3.4 2.1 3.4s1.1-2.1 2.5-2.1c1.1 0 1.9.8 1.9 1.9s-.8 1.9-1.9 1.9c-1.4 0-2.5-2.1-2.5-2.1S13.7 17.4 10 17.4c-2.9 0-4.6-2.4-4.6-5.4S7.1 6.6 10 6.6c2.1 0 3.5 1.3 4.6 2.7-1 1.3-2.1 3.4-2.1 3.4S11.4 10.6 10 10.6c-1.1 0-1.9.8-1.9 1.9s.8 1.9 1.9 1.9c1.4 0 2.5-2.1 2.5-2.1S15.1 6.6 18.6 6.6z"/></svg>',
    sprint: '<svg viewBox="0 0 24 24"><path d="M9 1h6v2H9zm3 4a8 8 0 1 0 0 16 8 8 0 0 0 0-16zm0 2a6 6 0 1 1 0 12 6 6 0 0 1 0-12zm-1 2h2v4.6l3 1.8-1 1.7-4-2.4z"/></svg>',
    streak: '<svg viewBox="0 0 24 24"><path d="M12 2c1 4-3 5-3 9a3 3 0 0 0 6 0c0-1.5-1-2.5-1-2.5s4 2 4 6.5a6 6 0 0 1-12 0C6 9 10 7 12 2z"/></svg>'
  };

  const pills = (name, options, current) =>
    `<div class="pills" data-pills="${name}">` +
    Object.keys(options).map((k) => `<button type="button" class="pill${k === current ? ' active' : ''}" data-value="${k}">${esc(options[k].title)}</button>`).join('') +
    '</div>';

  function setupCard() {
    const clefs = CLEF_CHOICES[settings.clefChoice].clefs;
    const summary = clefs.map((c) => CLEFS[c].title + ' ' + rangeSummary(settings.range, c)).join(' · ');
    return `<section class="card">
      <div class="field"><span class="label">Clef</span>${pills('clefChoice', CLEF_CHOICES, settings.clefChoice)}</div>
      <div class="field"><span class="label">Range</span>${pills('range', RANGES, settings.range)}</div>
      <div class="field"><span class="label">Answer with</span>${pills('answerMode', ANSWER_MODES, settings.answerMode)}</div>
      <p class="hint">${esc(summary)}</p>
    </section>`;
  }

  function isIOS() { return /iPhone|iPad|iPod/.test(navigator.userAgent) && !window.MSStream; }
  function isStandalone() { return window.navigator.standalone === true || window.matchMedia('(display-mode: standalone)').matches; }

  function renderHome() {
    const previewClef = settings.clefChoice === 'bass' ? 'bass' : 'treble';
    const previewNote = previewClef === 'bass' ? Note.make(1, 3) : Note.make(4, 4);
    const best = (mode) => {
      if (mode === 'sprint') { const b = stats.sprintBest(settings.clefChoice, settings.range); return b === null ? '' : `<span class="best">Best: ${b} points</span>`; }
      if (mode === 'streak') { const b = stats.streakBest(settings.clefChoice, settings.range); return b ? `<span class="best">Best: ${b} in a row</span>` : ''; }
      return '';
    };
    const banner = isIOS() && !isStandalone() && !settings.installHintDismissed
      ? `<div class="banner"><div><strong>Add to Home Screen</strong>Tap Share (the square with an arrow), then “Add to Home Screen”. It then opens like a normal app.</div><button type="button" class="close" data-action="dismiss-install" aria-label="Dismiss">✕</button></div>`
      : '';
    app.innerHTML = `<div class="screen home">
      <header>
        <h1>Note Reader</h1>
        <p class="subtitle">Read notes faster, one at a time.</p>
      </header>
      <div class="card tight">${staffSVG(previewClef, previewNote, 120)}</div>
      ${banner}
      ${setupCard()}
      <div class="stack">
        ${Object.keys(MODES).map((m) => `<button type="button" class="card mode" data-action="play" data-mode="${m}">
          <span class="icon">${ICONS[m]}</span>
          <span class="text"><span class="title">${MODES[m].title}</span><span class="sub">${MODES[m].sub}</span>${best(m)}</span>
          <span class="chev">›</span>
        </button>`).join('')}
      </div>
      <div class="row">
        <button type="button" class="btn secondary" data-action="nav" data-screen="stats">Stats</button>
        <button type="button" class="btn secondary" data-action="nav" data-screen="settings">Settings</button>
      </div>
    </div>`;
  }

  function lettersHTML(s) {
    const notes = s.answerNotes;
    const octaves = Array.from(new Set(notes.map((n) => n.octave))).sort((a, b) => a - b);
    const fb = s.feedback;
    const disabled = s.phase !== 'playing' ? ' disabled' : '';
    let html = '<div class="letters">';
    octaves.forEach((oct, row) => {
      notes.filter((n) => n.octave === oct).forEach((n) => {
        let cls = 'letter';
        if (fb) {
          if (Note.eq(n, fb.expected.note)) cls += ' correct';
          else if (!fb.correct && Note.eq(n, fb.answered)) cls += ' wrong';
        }
        html += `<button type="button" class="${cls}" style="grid-row:${row + 1};grid-column:${n.letter + 1}" data-action="answer" data-note="${Note.id(n)}"${disabled}>${Note.czech(n)}</button>`;
      });
    });
    return html + '</div>';
  }

  function pianoHTML(s) {
    const notes = s.answerNotes;
    const fb = s.feedback;
    const disabled = s.phase !== 'playing' ? ' disabled' : '';
    let html = `<div class="piano-wrap"><div class="piano" style="--n:${notes.length}">`;
    notes.forEach((n) => {
      let cls = 'key';
      if (fb) {
        if (Note.eq(n, fb.expected.note)) cls += fb.correct ? ' correct' : ' hint';
        else if (!fb.correct && Note.eq(n, fb.answered)) cls += ' wrong';
      }
      html += `<button type="button" class="${cls}" data-action="answer" data-note="${Note.id(n)}"${disabled}>${settings.pianoLabels ? Note.czech(n) : ''}</button>`;
    });
    notes.forEach((n, i) => {
      if (HAS_BLACK_ABOVE[n.letter] && i < notes.length - 1) html += `<span class="black" style="--i:${i + 1}"></span>`;
    });
    return html + '</div></div>';
  }

  function statusHTML(s) {
    if (s.mode === 'practice') {
      return `<div class="status"><span class="cap">Practice</span><span class="stats"><span>${s.correct}/${s.attempts}</span><span>${fmt.percent(s.accuracy)}</span><span>${fmt.seconds(s.averageMs)}</span></span></div>`;
    }
    if (s.mode === 'sprint') {
      return `<div class="status"><span class="big${s.timeRemaining <= 10 ? ' urgent' : ''}">${fmt.clock(s.timeRemaining)}</span><span class="cap">Score ${s.score}</span></div>`;
    }
    return `<div class="status"><span class="big"><span class="flame">🔥</span> ${s.streak}</span><span class="cap">Streak</span></div>`;
  }

  function feedbackHTML(s) {
    const fb = s.feedback;
    if (fb && s.phase === 'feedback') {
      if (fb.correct) return `<div class="feedback correct">✓ <b>Correct</b> · ${fmt.seconds(fb.ms)}</div>`;
      return `<div class="feedback wrong">✕ It was <span class="note">${Note.czech(fb.expected.note)}</span> · ${fmt.seconds(fb.ms)}</div>`;
    }
    if (s.isRetry) return `<div class="feedback again">✦ Again — this one tripped you up</div>`;
    if (s.lastMs !== null) return `<div class="feedback">Last answer ${fmt.seconds(s.lastMs)}</div>`;
    return `<div class="feedback">Which note is this?</div>`;
  }

  function renderGame() {
    const s = state.session;
    if (s.phase === 'finished') { renderResults(); return; }
    const flash = s.phase === 'feedback' && s.feedback ? (s.feedback.correct ? ' correct' : ' wrong') : '';
    app.innerHTML = `<div class="screen game">
      <div class="topbar">
        <button type="button" class="iconbtn" data-action="home" aria-label="Close">✕</button>
        ${statusHTML(s)}
        <span class="spacer"></span>
      </div>
      <section class="card staff-card${flash}">
        <div class="meta"><span>${CLEFS[s.prompt.clef].title} clef</span>${s.isRetry && s.phase === 'playing' ? '<span class="again">↻ Again</span>' : ''}</div>
        ${staffSVG(s.prompt.clef, s.prompt.note, 230)}
      </section>
      ${feedbackHTML(s)}
      <div class="answers">${settings.answerMode === 'piano' ? pianoHTML(s) : lettersHTML(s)}</div>
    </div>`;
  }

  function renderResults() {
    const s = state.session;
    const title = s.mode === 'sprint' ? "Time's up!" : s.mode === 'streak' ? 'Streak over' : 'Nice practice';
    const value = s.mode === 'sprint' ? s.score : s.mode === 'streak' ? s.bestStreak : s.correct;
    const under = s.mode === 'sprint' ? 'points' : s.mode === 'streak' ? 'in a row' : 'correct';
    const best = s.isNewBest ? '<div class="newbest">★ New personal best!</div>' : (s.personalBest !== null ? `<div class="under">Personal best: ${s.personalBest}</div>` : '');
    app.innerHTML = `<div class="screen"><div class="results">
      <h1>${title}</h1>
      <div><div class="huge">${value}</div><div class="under">${under}</div></div>
      ${best}
      <section class="card">
        <div class="statrow"><span>Correct</span><span>${s.correct}</span></div>
        <div class="statrow"><span>Wrong</span><span>${s.wrong}</span></div>
        <div class="statrow"><span>Accuracy</span><span>${fmt.percent(s.accuracy)}</span></div>
        <div class="statrow"><span>Average time</span><span>${fmt.seconds(s.averageMs)}</span></div>
      </section>
      <div class="stack actions">
        <button type="button" class="btn primary" data-action="play" data-mode="${s.mode}">Play again</button>
        <button type="button" class="btn secondary" data-action="home">Home</button>
      </div>
    </div></div>`;
  }

  function mastery(e) {
    if (!e || !e.attempts) return 'unseen';
    if (accuracyOf(e) >= 0.85 && averageOf(e) <= 2500) return 'strong';
    if (accuracyOf(e) >= 0.6) return 'okay';
    return 'learning';
  }

  function renderStats() {
    const t = stats.totals();
    const grid = (clef) => `<section class="card"><h2>${CLEFS[clef].title} clef</h2><div class="grid7">` +
      rangeNotes('intermediate', clef).map((n) => {
        const e = stats.get({ clef, note: n });
        return `<div class="cell ${mastery(e)}"><span class="n">${Note.czech(n)}</span><span class="p">${e ? fmt.percent(accuracyOf(e)) : '–'}</span></div>`;
      }).join('') + '</div></section>';
    const slow = Object.keys(stats.data.notes)
      .map((k) => ({ prompt: parsePromptKey(k), e: stats.data.notes[k] }))
      .filter((x) => x.prompt && x.e.attempts >= 2)
      .sort((a, b) => averageOf(b.e) - averageOf(a.e))
      .slice(0, 6);
    app.innerHTML = `<div class="screen">
      <div class="nav"><button type="button" class="iconbtn" data-action="home" aria-label="Back">‹</button><h2>Stats</h2><span class="spacer" style="width:40px"></span></div>
      <section class="card summary">
        <div><div class="v">${t.attempts}</div><div class="l">Answers</div></div>
        <div><div class="v">${t.attempts ? fmt.percent(t.accuracy) : '–'}</div><div class="l">Accuracy</div></div>
        <div><div class="v">${t.seen}</div><div class="l">Notes seen</div></div>
      </section>
      ${grid('treble')}
      ${grid('bass')}
      <section class="card"><h2>Slowest notes</h2>
        ${slow.length ? slow.map((x) => `<div class="slow"><span class="n">${Note.czech(x.prompt.note)}</span><span class="c">${CLEFS[x.prompt.clef].title}</span><span class="a">${fmt.percent(accuracyOf(x.e))}</span><span class="t">${fmt.seconds(averageOf(x.e))}</span></div>`).join('')
                     : '<p class="hint">Play a few rounds and your slowest notes will show up here.</p>'}
      </section>
      <div class="legend"><span><i style="background:var(--correct)"></i>Strong</span><span><i style="background:var(--amber)"></i>Getting there</span><span><i style="background:var(--wrong)"></i>Needs work</span></div>
    </div>`;
  }

  function renderSettings() {
    const toggle = (key, label, note) => `<div class="toggle"><span>${label}${note ? `<br><span class="hint small">${note}</span>` : ''}</span><button type="button" class="switch${settings[key] ? ' on' : ''}" role="switch" aria-checked="${!!settings[key]}" data-action="toggle" data-key="${key}" aria-label="${label}"></button></div>`;
    const rangeNote = settings.range === 'beginner' ? 'Treble c1–g2, bass F–c1. Only the c1 ledger line.' : 'Treble a–c3, bass C–e1. Two ledger lines above and below.';
    app.innerHTML = `<div class="screen">
      <div class="nav"><button type="button" class="iconbtn" data-action="home" aria-label="Back">‹</button><h2>Settings</h2><span class="spacer" style="width:40px"></span></div>
      <section class="card">
        <div class="field"><span class="label">Clef</span>${pills('clefChoice', CLEF_CHOICES, settings.clefChoice)}</div>
        <div class="field"><span class="label">Range</span>${pills('range', RANGES, settings.range)}<p class="hint small">${rangeNote}</p></div>
        <div class="field"><span class="label">Answer with</span>${pills('answerMode', ANSWER_MODES, settings.answerMode)}</div>
      </section>
      <section class="card">
        ${toggle('pianoLabels', 'Letter labels on piano keys')}
        ${toggle('soundOn', 'Sound', 'Silent switch mutes sounds.')}
        ${toggle('hapticsOn', 'Haptics', 'Not supported by Safari on iPhone.')}
      </section>
      <section class="card"><button type="button" class="btn danger" data-action="reset">🗑 Reset stats and personal bests</button></section>
      <p class="foot">Note Reader · web version<br>Czech note names (h instead of b). Middle C is c1.</p>
    </div>`;
  }

  function render() {
    switch (state.screen) {
      case 'game': renderGame(); break;
      case 'stats': renderStats(); break;
      case 'settings': renderSettings(); break;
      default: renderHome();
    }
  }

  // ───────────────────────── Actions ─────────────────────────
  function startGame(mode) {
    if (state.session) state.session.stop();
    state.session = new GameSession(mode, () => { if (state.screen === 'game') renderGame(); });
    state.screen = 'game';
    render();
    state.session.start();
  }

  function goHome() {
    if (state.session) { state.session.stop(); state.session = null; }
    state.screen = 'home';
    render();
  }

  app.addEventListener('click', (event) => {
    const pill = event.target.closest('.pill');
    if (pill) {
      const group = pill.closest('[data-pills]');
      settings[group.dataset.pills] = pill.dataset.value;
      saveSettings();
      render();
      return;
    }
    const el = event.target.closest('[data-action]');
    if (!el) return;
    switch (el.dataset.action) {
      case 'play': synth.unlock(); startGame(el.dataset.mode); break;
      case 'home': goHome(); break;
      case 'nav': state.screen = el.dataset.screen; render(); break;
      case 'answer': {
        const m = /^([CDEFGAH])(-?\d+)$/.exec(el.dataset.note);
        if (m && state.session) state.session.answer(Note.make(LETTERS.indexOf(m[1].toLowerCase()), parseInt(m[2], 10)));
        break;
      }
      case 'toggle': settings[el.dataset.key] = !settings[el.dataset.key]; saveSettings(); render(); break;
      case 'reset':
        if (window.confirm('Reset all stats? Per-note statistics, sprint scores and best streaks will be deleted.')) { stats.reset(); render(); }
        break;
      case 'dismiss-install': settings.installHintDismissed = true; saveSettings(); render(); break;
      default: break;
    }
  });

  // Keyboard support for desktop testing: letters c d e f g a h answer the lowest matching octave.
  document.addEventListener('keydown', (event) => {
    if (state.screen !== 'game' || !state.session) return;
    const idx = LETTERS.indexOf(event.key.toLowerCase());
    if (idx < 0) return;
    const note = state.session.answerNotes.find((n) => n.letter === idx);
    if (note) state.session.answer(note);
  });

  document.addEventListener('visibilitychange', () => {
    if (document.hidden && state.session && state.session.mode === 'sprint' && state.session.phase !== 'finished') state.session.finish();
  });

  if ('serviceWorker' in navigator) {
    window.addEventListener('load', () => { navigator.serviceWorker.register('sw.js').catch(() => {}); });
  }

  render();
})();
