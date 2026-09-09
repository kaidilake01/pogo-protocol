import {
  concat,
  encodeAbiParameters,
  getCreate2Address,
  keccak256,
  toHex,
  type Address,
  type Hex,
} from "viem";
export function cloneInitCodeHash(implementation: Address): Hex {
  return keccak256(
    concat([
      "0x3d602d80600a3d3981f3",
      "0x363d3d373d3d3d363d73",
      implementation,
      "0x5af43d82803e903d91602b57fd5bf3",
    ]),
  );
}
export function predictVanity(
  factory: Address,
  implementation: Address,
  creator: Address,
  salt: Hex,
) {
  const effective = keccak256(
    encodeAbiParameters(
      [{ type: "address" }, { type: "bytes32" }],
      [creator, salt],
    ),
  );
  return getCreate2Address({
    from: factory,
    salt: effective,
    bytecodeHash: cloneInitCodeHash(implementation),
  });
}
export function candidate(
  factory: Address,
  hash: Hex,
  creator: Address,
  index: bigint,
) {
  const salt = toHex(index, { size: 32 });
  const effective = keccak256(
    encodeAbiParameters(
      [{ type: "address" }, { type: "bytes32" }],
      [creator, salt],
    ),
  );
  return {
    salt,
    address: getCreate2Address({
      from: factory,
      salt: effective,
      bytecodeHash: hash,
    }),
  };
}
