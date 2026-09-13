import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';

// solc 0.8.28, IPFS metadata: CBOR map containing ipfs (34 bytes) and solc (3 bytes).
// Validate the full envelope so an arbitrary code range cannot be treated as metadata.
const metadataPrefix = Buffer.from('a2646970667358221220', 'hex');
const metadataSuffix = Buffer.from('64736f6c634300081c0033', 'hex');
function assertMetadata(bytes) {
  assert.equal(bytes.length, 53, 'Unexpected Solidity metadata size');
  assert(bytes.subarray(0, 10).equals(metadataPrefix), 'Invalid Solidity IPFS metadata prefix');
  assert(bytes.subarray(42).equals(metadataSuffix), 'Invalid Solidity metadata compiler/footer');
}

export function normalizedRuntimeHash(bytecode, entry) {
  assert.match(bytecode, /^(?:0x)?(?:[0-9a-fA-F]{2})+$/, 'Invalid runtime bytecode');
  const bytes = Buffer.from(bytecode.replace(/^0x/, ''), 'hex');
  assert.equal(bytes.length, entry.runtimeBytes, 'Runtime size changed');
  assertMetadata(bytes.subarray(-53));
  const executable = Buffer.from(bytes.subarray(0, -53));
  const embedded = entry.embeddedMetadata;
  let lastEnd = 0;
  for (const range of entry.immutableRanges) {
    assert(Number.isInteger(range.start) && Number.isInteger(range.length), 'Invalid immutable range');
    assert(range.start >= lastEnd && range.length > 0 && range.start + range.length <= executable.length, 'Invalid immutable bounds');
    for (const metadata of embedded) {
      assert(range.start + range.length <= metadata.start || range.start >= metadata.start + metadata.length, 'Immutable overlaps metadata');
    }
    executable.fill(0, range.start, range.start + range.length);
    lastEnd = range.start + range.length;
  }
  for (const metadata of embedded) {
    assert(Number.isInteger(metadata.start) && metadata.start >= 0, 'Invalid embedded metadata offset');
    assert.equal(metadata.length, 53, 'Invalid embedded metadata length');
    assert(metadata.start + metadata.length <= executable.length, 'Embedded metadata outside runtime');
    assertMetadata(executable.subarray(metadata.start, metadata.start + metadata.length));
    // Keep the child metadata structure, compiler version, and length byte-for-byte;
    // source directory changes are allowed to alter only its 32-byte IPFS digest.
    executable.fill(0, metadata.start + 10, metadata.start + 42);
  }
  return createHash('sha256').update(executable).digest('hex');
}

export function verifyRuntimeArtifact(artifact, entry, manifest) {
  assert.equal(artifact.metadata.compiler.version, manifest.compiler, 'Compiler version changed');
  for (const [key, value] of Object.entries(manifest.settings)) {
    assert.deepEqual(artifact.metadata.settings[key], value, `Compiler setting changed: ${key}`);
  }
  assert.deepEqual(artifact.metadata.settings.compilationTarget, entry.source, 'Compilation target changed');
  const ranges = Object.values(artifact.deployedBytecode.immutableReferences ?? {}).flat().sort((a, b) => a.start - b.start);
  assert.deepEqual(ranges, entry.immutableRanges, 'Compiler immutable layout changed');
  assert.equal(normalizedRuntimeHash(artifact.deployedBytecode.object, entry), entry.normalizedExecutableSha256, `${entry.name}: executable differs from the mainnet deployment build`);
}
