import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=process.cwd();
const rules=JSON.parse(fs.readFileSync('docs/current-rules.json','utf8'));
assert.deepEqual(rules.rewardSplitBps,[400,1600,8000]);
assert.equal(rules.activeDays,90);
assert.equal(rules.lockHours,24);
assert.equal(rules.earlyExitBps,1000);
assert.equal(rules.graduationTargetBNB,'0.01');
const deployment=JSON.parse(fs.readFileSync('docs/deployments/bsc-mainnet.json','utf8'));
assert.deepEqual(deployment.enabledTemplateIds,[rules.miningTemplateId,rules.transferTemplateId]);
for(const [key,address] of Object.entries(rules.addresses)){
 const actual=deployment[key==='transferCurveDeployer'?'fairCurveDeployer':key];
 if(actual)assert.equal(address.toLowerCase(),actual.toLowerCase(),`Address mismatch: ${key}`);
}
const files=[];
function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){if(['node_modules','.git','out','cache','dist'].includes(e.name))continue;const p=path.join(dir,e.name);if(e.isDirectory())walk(p);else if(p.endsWith('.md'))files.push(p);}}
walk(root);
for(const file of files){
 const text=fs.readFileSync(file,'utf8');
 assert(!/6\.666|QuoteRevenueForkTest|templates 9 and 10|Graduation seeding fee/.test(text),`Stale documentation: ${file}`);
 for(const m of text.matchAll(/\]\(([^\s)]+)(?:\s+"[^"]*")?\)/g)){
  const url=m[1];if(/^(?:https?:|mailto:|#)/.test(url))continue;
  const target=decodeURIComponent(url.split('#')[0]);if(target)assert(fs.existsSync(path.resolve(path.dirname(file),target)),`Broken local link: ${file} -> ${url}`);
 }
}
const economic=fs.readFileSync('docs/economics.md','utf8');
for(const bps of rules.rewardSplitBps)assert(economic.includes(`${bps/100}%`));
assert(fs.existsSync('tests/contracts/FixedAllocationFork.t.sol'));
console.log(`Documentation checks passed: ${files.length} Markdown files, current rules and local links.`);
