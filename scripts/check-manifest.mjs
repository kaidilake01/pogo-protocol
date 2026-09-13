import { readFileSync, readdirSync } from "node:fs";
import { createHash } from "node:crypto";
import path from "node:path";
import assert from "node:assert/strict";
import { verifyRuntimeArtifact } from './runtime-manifest.mjs';
const manifest = JSON.parse(readFileSync("docs/source-manifest.json", "utf8"));
for (const [path, hash] of Object.entries(manifest.files)) {
  const actual = createHash("sha256").update(readFileSync(path)).digest("hex");
  if (actual !== hash) throw Error("Source manifest mismatch: " + path);
}
function sources(directory) {
  return readdirSync(directory, { withFileTypes: true }).flatMap(entry => {
    const name = `${directory}/${entry.name}`;
    return entry.isDirectory() ? sources(name) : name.endsWith('.sol') ? [name] : [];
  });
}
const contracts = sources('contracts');
const shipped = [...contracts, ...sources('tests/contracts')].sort();
assert.deepEqual(Object.keys(manifest.files).sort(), shipped, 'Every shipped Solidity source must be in the manifest');
for (const entry of manifest.entrypoints) assert(entry in manifest.files, `Untracked entrypoint: ${entry}`);
const reached = new Set();
function visit(file) {
  if (reached.has(file)) return;
  assert(file in manifest.files, `Untracked local import: ${file}`);
  reached.add(file);
  for (const match of readFileSync(file, 'utf8').matchAll(/\bimport\s+[^;]*?["']([^"']+)["']\s*;/g)) {
    if (match[1].startsWith('.')) visit(path.posix.normalize(path.posix.join(path.posix.dirname(file), match[1])));
  }
}
for (const entry of contracts.filter(file => file.startsWith('contracts/src/'))) visit(entry);
for (const file of contracts) assert(reached.has(file), `Production-unused Solidity source: ${file}`);
console.log(`Solidity source manifest verified: ${shipped.length} sources; ${reached.size} production dependencies.`);
const runtimes = JSON.parse(readFileSync('docs/runtime-manifest.json', 'utf8'));
assert.equal(runtimes.schemaVersion, 1, 'Unsupported runtime manifest schema');
assert.equal(runtimes.algorithm, 'sha256');
for (const entry of runtimes.contracts) {
  let artifact;
  try {
    artifact = JSON.parse(readFileSync(entry.artifact, 'utf8'));
  } catch (error) {
    throw new Error(`Build contract artifacts before checking runtimes: npm run build:contracts (${entry.artifact})`, { cause: error });
  }
  verifyRuntimeArtifact(artifact, entry, runtimes);
}
console.log(`Mainnet deployment executable fingerprints verified: ${runtimes.contracts.length} contracts (metadata and declared immutables normalized).`);
