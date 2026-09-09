import { readFileSync } from "node:fs";
import { createHash } from "node:crypto";
const manifest = JSON.parse(readFileSync("docs/source-manifest.json", "utf8"));
for (const [path, hash] of Object.entries(manifest.files)) {
  const actual = createHash("sha256").update(readFileSync(path)).digest("hex");
  if (actual !== hash) throw Error("Source manifest mismatch: " + path);
}
console.log("Solidity source manifest verified");
