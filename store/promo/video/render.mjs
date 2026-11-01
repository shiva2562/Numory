// Renders both cuts with HyperFrames, then swaps in the mastered soundtrack.
//
// HyperFrames mixes the <audio> track itself; each render's audio is replaced with assets/gen/soundtrack.wav
// (-14 LUFS, peaks under -2 dBTP) as 256 kbps AAC, and the video stream is copied as is.
//
//   node render.mjs                 # both, to ../renders/numory_promo_16x9.mp4 and numory_promo_9x16.mp4
//   node render.mjs portrait        # one of: landscape | portrait
//   node render.mjs -- --variables '{"cta":"Free on Google Play"}'   # extra arguments for hyperframes render
//   node render.mjs --suffix=_live -- --variables '{"cta":"Free on Google Play"}'   # write numory_promo_16x9_live.mp4
//   node render.mjs --mux-only      # keep the rendered picture, just put the current soundtrack.wav in
import { spawnSync } from 'node:child_process';
import { renameSync, rmSync, mkdirSync } from 'node:fs';
import path from 'node:path';
import { fileURLToPath } from 'node:url';

const here = path.dirname(fileURLToPath(import.meta.url));
const out = path.join(here, '..', 'renders');
const CUTS = { landscape: 'numory_promo_16x9', portrait: 'numory_promo_9x16' };
const dash = process.argv.indexOf('--');
const args = dash < 0 ? process.argv.slice(2) : process.argv.slice(2, dash);
const muxOnly = args.includes('--mux-only');
const suffix = (args.find(a => a.startsWith('--suffix=')) || '--suffix=').slice(9);
const names = args.filter(a => !a.startsWith('--'));
const extra = dash < 0 ? [] : process.argv.slice(dash + 1);

function run(cmd, args, cwd) {
  const r = spawnSync(cmd, args, { cwd, stdio: 'inherit' });
  if (r.status !== 0) throw new Error(`${cmd} ${args.join(' ')} failed`);
}

mkdirSync(out, { recursive: true });
for (const name of names.length ? names : Object.keys(CUTS)) {
  const final = path.join(out, CUTS[name] + suffix + '.mp4');
  const raw = final.replace(/\.mp4$/, '.hf.mp4');
  if (muxOnly) renameSync(final, raw);
  else run('npx', ['hyperframes', 'render', '-f', '60', '-q', 'looks', '-o', raw, '--quiet', ...extra], path.join(here, name));
  run('ffmpeg', ['-y', '-loglevel', 'error', '-i', raw, '-i', path.join(here, 'assets', 'gen', 'soundtrack.wav'),
    '-map', '0:v', '-map', '1:a', '-c:v', 'copy', '-c:a', 'aac', '-b:a', '256k', '-shortest', '-movflags', '+faststart', final + '.tmp.mp4'], here);
  renameSync(final + '.tmp.mp4', final);
  rmSync(raw);
  console.log(`${name}: ${path.relative(process.cwd(), final)}`);
}
