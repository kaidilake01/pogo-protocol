import test from 'node:test';
import assert from 'node:assert/strict';
import { normalizedRuntimeHash } from '../../scripts/runtime-manifest.mjs';

const metadata = digest => Buffer.from(`a2646970667358221220${digest.repeat(32)}64736f6c634300081c0033`, 'hex');
function fixture(outer = '11', inner = '22') {
  const bytes = Buffer.concat([Buffer.from('600160020100', 'hex'), metadata(inner), metadata(outer)]);
  return { bytes, entry: { runtimeBytes: bytes.length, immutableRanges: [{ start: 1, length: 1 }], embeddedMetadata: [{ start: 6, length: 53, contract: 'Child' }] } };
}
test('normalization permits only declared immutable values and metadata digests', () => {
  const initial = fixture();
  const changed = fixture('33', '44');
  changed.bytes[1] = 254;
  assert.equal(normalizedRuntimeHash(initial.bytes.toString('hex'), initial.entry), normalizedRuntimeHash(changed.bytes.toString('hex'), changed.entry));
});
test('an executable instruction change changes the fingerprint', () => {
  const { bytes, entry } = fixture();
  const before = normalizedRuntimeHash(bytes.toString('hex'), entry);
  bytes[4] = 2;
  assert.notEqual(normalizedRuntimeHash(bytes.toString('hex'), entry), before);
});
test('embedded metadata cannot conceal changed compiler or structural bytes', () => {
  const { bytes, entry } = fixture();
  bytes[6 + 49] = 29;
  assert.throws(() => normalizedRuntimeHash(bytes.toString('hex'), entry), /metadata compiler/);
});
test('invalid immutable bounds, metadata overlap and runtime size are rejected', () => {
  const { bytes, entry } = fixture();
  assert.throws(() => normalizedRuntimeHash(bytes.toString('hex'), { ...entry, immutableRanges: [{ start: 500, length: 1 }] }), /immutable bounds/);
  assert.throws(() => normalizedRuntimeHash(bytes.toString('hex'), { ...entry, immutableRanges: [{ start: 5, length: 2 }] }), /overlaps metadata/);
  assert.throws(() => normalizedRuntimeHash(bytes.subarray(1).toString('hex'), entry), /Runtime size changed/);
});
