import fs from 'node:fs';
import path from 'node:path';
import assert from 'node:assert/strict';
const root=process.cwd();
const rules=JSON.parse(fs.readFileSync('docs/current-rules.json','utf8'));
assert.deepEqual(rules.rewardSplitBps,[400,1600,8000]);
assert.equal(rules.activeDays,90);
assert.equal(rules.lockHours,24);
assert.equal(rules.earlyExitBps,1000);
assert.equal(rules.graduationTargetBNB,'6.666');
assert.equal(rules.miningTemplateId,13);
assert.equal(rules.curveVersion,15);
assert.equal(rules.miningVersion,14);
assert.equal(rules.miningDeployment,'graduation');
const deployment=JSON.parse(fs.readFileSync('docs/deployments/bsc-mainnet.json','utf8'));
assert.deepEqual(deployment.enabledTemplateIds,[rules.miningTemplateId,rules.transferTemplateId]);
assert.equal(deployment.curveVersion,rules.curveVersion);
assert.equal(deployment.defaultTemplateId,rules.miningTemplateId);
for(const [key,address] of Object.entries(rules.addresses)){
 const actual=deployment[key==='transferCurveDeployer'?'fairCurveDeployer':key];
 if(actual)assert.equal(address.toLowerCase(),actual.toLowerCase(),`Address mismatch: ${key}`);
}
const files=[];
function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){if(['node_modules','.git','out','cache','dist'].includes(e.name))continue;const p=path.join(dir,e.name);if(e.isDirectory())walk(p);else if(p.endsWith('.md'))files.push(p);}}
walk(root);
for(const file of files){
 const text=fs.readFileSync(file,'utf8');
 assert(!/0\.01 BNB[- ](?:test|equivalent)|\.01 target|6\.6666|6\.25%|31\.25%|62\.5%|QuoteRevenueForkTest|templates 9 and 10|Graduation seeding fee|[Tt]emplate 12|Default template ID is 11|curve version 11/.test(text),`Stale documentation: ${file}`);
 for(const m of text.matchAll(/\]\(([^\s)]+)(?:\s+"[^"]*")?\)/g)){
  const url=m[1];if(/^(?:https?:|mailto:|#)/.test(url))continue;
  const target=decodeURIComponent(url.split('#')[0]);if(target)assert(fs.existsSync(path.resolve(path.dirname(file),target)),`Broken local link: ${file} -> ${url}`);
 }
}
const economic=fs.readFileSync('docs/economics.md','utf8');
for(const bps of rules.rewardSplitBps)assert(economic.includes(`${bps/100}%`));
assert(fs.existsSync('tests/contracts/FixedAllocationFork.t.sol'));
console.log(`Documentation checks passed: ${files.length} Markdown files, current rules and local links.`);
