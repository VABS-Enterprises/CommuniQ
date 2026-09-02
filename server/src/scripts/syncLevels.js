/*
 * Copies the authored curriculum (repo root) into the server's runtime copy.
 *
 * The root file is the one to edit. The server reads its own copy because
 * Render deploys the Node service with `rootDir: server`, so a path that
 * climbs out of that directory is not safe to depend on at runtime.
 *
 *   npm run levels:sync         copy root -> server/src/data/learningLevels.json
 *   npm run levels:check        exit 1 if they differ (for CI / pre-deploy)
 */
const fs = require('fs');
const path = require('path');

const SOURCE = path.join(__dirname, '..', '..', '..', 'communiq_levels_1_20.json');
const TARGET = path.join(__dirname, '..', 'data', 'learningLevels.json');

const checkOnly = process.argv.includes('--check');

if (!fs.existsSync(SOURCE)) {
  console.error(`Source curriculum not found at ${SOURCE}`);
  process.exit(1);
}

const source = fs.readFileSync(SOURCE, 'utf8');
const target = fs.existsSync(TARGET) ? fs.readFileSync(TARGET, 'utf8') : null;

if (source === target) {
  console.log('Curriculum in sync.');
  process.exit(0);
}

if (checkOnly) {
  console.error('Curriculum OUT OF SYNC — run `npm run levels:sync`.');
  process.exit(1);
}

// Parse before writing so a malformed edit never reaches the runtime copy.
const parsed = JSON.parse(source);
const count = Array.isArray(parsed.levels) ? parsed.levels.length : 0;
fs.writeFileSync(TARGET, source);
console.log(`Synced ${count} levels -> ${path.relative(process.cwd(), TARGET)}`);
