#!/usr/bin/env node
/**
 * Anchored Daily — Daily Devotional Generator
 * Runs each morning via cron. Picks today's verse, generates HTML,
 * archives yesterday's as a dated page, updates index + archive.
 */

const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');

const BASE = path.resolve(__dirname, '..');
const VERSES_FILE = path.join(__dirname, 'verses.json');
const STATE_FILE = path.join(__dirname, 'state.json');
const DEVOTIONALS_DIR = path.join(BASE, 'devotionals');
const INDEX_FILE = path.join(BASE, 'index.html');
const ARCHIVE_FILE = path.join(BASE, 'archive.html');

// Load verse list
const verses = JSON.parse(fs.readFileSync(VERSES_FILE, 'utf8'));

// Load/init state
let state = { lastIndex: -1, lastDate: null };
if (fs.existsSync(STATE_FILE)) {
  state = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
}

// Pick next verse (sequential, wraps around)
const nextIndex = (state.lastIndex + 1) % verses.length;
const d = verses[nextIndex];

// Today's date info
const now = new Date();
const dateStr = now.toLocaleDateString('en-US', {
  weekday: 'long', year: 'numeric', month: 'long', day: 'numeric',
  timeZone: 'America/Indiana/Indianapolis'
});
const isoDate = now.toLocaleDateString('en-CA', { timeZone: 'America/Indiana/Indianapolis' }); // YYYY-MM-DD
const slug = isoDate; // e.g. 2026-04-02

// --- NAV HTML (shared) ---
const nav = `
  <header class="border-b border-stone-200 bg-white">
    <div class="max-w-2xl mx-auto px-6 py-5 flex items-center justify-between">
      <a href="/anchoreddaily/" class="text-stone-900 no-underline">
        <h1 class="text-xl font-semibold tracking-tight">⚓ Anchored Daily</h1>
        <p class="text-xs text-stone-400 mt-0.5 font-light">Scripture &amp; Reflection</p>
      </a>
      <nav class="flex gap-4 text-sm text-stone-500">
        <a href="/anchoreddaily/" class="hover:text-stone-900 transition-colors">Today</a>
        <a href="/anchoreddaily/archive.html" class="hover:text-stone-900 transition-colors">Archive</a>
        <a href="/anchoreddaily/plan.html" class="hover:text-stone-900 transition-colors">The Plan</a>
        <a href="/anchoreddaily/about.html" class="hover:text-stone-900 transition-colors">About</a>
      </nav>
    </div>
  </header>`.trim();

const head = (title) => `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1.0" />
  <title>${title} — Anchored Daily</title>
  <script src="https://cdn.tailwindcss.com"><\/script>
  <style>
    @import url('https://fonts.googleapis.com/css2?family=Merriweather:ital,wght@0,300;0,400;0,700;1,300;1,400&family=Inter:wght@300;400;500;600&display=swap');
    .font-serif { font-family: 'Merriweather', Georgia, serif; }
    .font-sans { font-family: 'Inter', system-ui, sans-serif; }
  </style>
</head>
<body class="bg-stone-50 text-stone-800 font-sans min-h-screen">`;

const foot = `  <footer class="border-t border-stone-200 mt-16">
    <div class="max-w-2xl mx-auto px-6 py-8 text-center">
      <p class="text-xs text-stone-400">"We have this hope as an anchor for the soul." — Heb 6:19</p>
    </div>
  </footer>
</body>
</html>`;

// --- Generate today's devotional content block ---
function devotionalContent(verse, dateLabel, backLink = null) {
  const reflectionHtml = verse.reflection.map(p => `        <p>${p}</p>`).join('\n');
  return `
  <main class="max-w-2xl mx-auto px-6 py-12">
    <p class="text-xs font-medium uppercase tracking-widest text-stone-400 mb-6">${dateLabel}</p>
    <div class="bg-white rounded-2xl border border-stone-200 p-8 mb-8 shadow-sm">
      <p class="text-xs font-medium uppercase tracking-widest text-amber-600 mb-4">${verse.theme}</p>
      <blockquote class="font-serif text-xl leading-relaxed text-stone-800 mb-5 italic">
        "${verse.verse}"
      </blockquote>
      <cite class="text-sm font-medium text-stone-500 not-italic">— ${verse.ref}</cite>
    </div>
    <div class="mb-10">
      <h2 class="font-serif text-lg font-bold text-stone-900 mb-4">Reflection</h2>
      <div class="text-stone-600 leading-relaxed space-y-4 text-base">
${reflectionHtml}
      </div>
    </div>
    <div class="border-l-2 border-amber-200 pl-6 mb-10">
      <p class="text-xs font-medium uppercase tracking-widest text-stone-400 mb-3">A Prayer</p>
      <p class="text-stone-600 italic font-serif leading-relaxed">${verse.prayer}</p>
    </div>
    ${backLink ? `<a href="${backLink}" class="text-sm text-stone-400 hover:text-stone-700 transition-colors">← All devotionals</a>` : `
    <div class="flex items-center justify-between text-sm">
      <a href="/anchoreddaily/archive.html" class="text-stone-400 hover:text-stone-700 transition-colors">View all devotionals →</a>
      <button onclick="share()" class="text-stone-400 hover:text-stone-700 transition-colors underline underline-offset-2">Share today's verse</button>
    </div>
    <div class="mt-12 bg-amber-50 border border-amber-200 rounded-2xl p-6 flex items-center justify-between gap-4">
      <div>
        <p class="font-semibold text-stone-800 text-sm">Ready to build the habit?</p>
        <p class="text-stone-500 text-xs mt-1">A 3-phase soul training plan — 5 minutes a day to start.</p>
      </div>
      <a href="/anchoreddaily/plan.html" class="bg-amber-500 hover:bg-amber-600 text-white text-sm font-medium px-4 py-2 rounded-lg transition-colors whitespace-nowrap">See The Plan</a>
    </div>`}
  </main>`;
}

// --- 1. Write today's index.html ---
const indexHtml = `${head('Anchored Daily — Scripture & Reflection')}
${nav}
${devotionalContent(d, dateStr)}
${foot}
<script>
  function share() {
    const text = '"${d.verse.replace(/'/g,"\\'")}\" — ${d.ref}';
    if (navigator.share) {
      navigator.share({ title: 'Anchored Daily', text, url: window.location.href });
    } else {
      navigator.clipboard.writeText(window.location.href).then(() => {
        const btn = document.querySelector('button');
        btn.textContent = 'Copied!';
        setTimeout(() => btn.textContent = "Share today's verse", 2000);
      });
    }
  }
<\/script>
</html>`;

// Remove the duplicate </html> from foot since we add our own
const finalIndex = indexHtml.replace('</body>\n</html>\n<script>', '<script>').replace('</html>\n</html>', '</html>');
fs.writeFileSync(INDEX_FILE, finalIndex);
console.log(`✅ index.html updated with: ${d.ref}`);

// --- 2. Archive today as a dated page ---
const archivedHtml = `${head(d.ref)}
${nav}
${devotionalContent(d, dateStr, '/anchoreddaily/archive.html')}
${foot}`;
const archivedPath = path.join(DEVOTIONALS_DIR, `${slug}.html`);
fs.writeFileSync(archivedPath, archivedHtml);
console.log(`✅ Archived as devotionals/${slug}.html`);

// --- 3. Rebuild archive.html ---
// Collect all dated devotionals
const allFiles = fs.readdirSync(DEVOTIONALS_DIR)
  .filter(f => /^\d{4}-\d{2}-\d{2}\.html$/.test(f))
  .sort()
  .reverse(); // newest first

// Also load metadata from each file (just parse the ref/theme/verse from filename → state lookup)
// We'll store a simple manifest in state
if (!state.manifest) state.manifest = [];

// Add today's entry if not already there
const existing = state.manifest.find(e => e.slug === slug);
if (!existing) {
  state.manifest.unshift({
    slug,
    date: dateStr,
    isoDate,
    ref: d.ref,
    theme: d.theme,
    preview: d.verse.substring(0, 80) + (d.verse.length > 80 ? '...' : '')
  });
}

const archiveEntries = state.manifest.map(entry => `
      <a href="/anchoreddaily/devotionals/${entry.slug}.html" class="block bg-white rounded-xl border border-stone-200 p-6 hover:border-amber-300 transition-colors no-underline">
        <div>
          <p class="text-xs text-stone-400 mb-2">${entry.date} · ${entry.theme}</p>
          <p class="font-serif text-stone-800 italic mb-2">"${entry.preview}"</p>
          <p class="text-xs text-amber-600 font-medium">${entry.ref}</p>
        </div>
      </a>`).join('\n');

const archiveHtml = `${head('Archive')}
${nav}
  <main class="max-w-2xl mx-auto px-6 py-12">
    <h2 class="font-serif text-2xl font-bold text-stone-900 mb-2">Archive</h2>
    <p class="text-stone-400 text-sm mb-10">All devotionals, newest first</p>
    <div class="space-y-4">
${archiveEntries}
    </div>
  </main>
${foot}`;

fs.writeFileSync(ARCHIVE_FILE, archiveHtml);
console.log(`✅ archive.html rebuilt with ${state.manifest.length} entries`);

// --- 4. Save state ---
state.lastIndex = nextIndex;
state.lastDate = isoDate;
fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
console.log(`✅ State saved (next index: ${nextIndex})`);

// --- 5. Git commit + push ---
try {
  execSync(`cd ${path.resolve(BASE, '..')} && git add anchoreddaily/ && git commit -m "Devotional: ${d.ref} (${isoDate})" && git push origin master`, { stdio: 'inherit' });
  console.log('✅ Pushed to GitHub');
} catch (e) {
  console.error('❌ Git push failed:', e.message);
  process.exit(1);
}
