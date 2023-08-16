// This file to test generation of merkle root

const { MerkleTree } = require("merkletreejs");
const keccak256 = require("keccak256");

// List of 4 public Ethereum addresses
let addresses = [
  "0x4db8bcCF4385C7AA46F48eb42f70FA41Df917b44",
  "0xEab2B6b5a76d5878a7B5D97d7F6812Da09A30953",
  "0xCa2A82ea8e2890A476B6Ab1A109139087f831c47",
  "0x3AB8866082dcef761FB61F48aaBe7C5741fae889",
  "0x287f0b854a2ba9dc3e8572c68bdabd949819f119",
];

// Hash addresses to get the leaves
let leaves = addresses.map((addr) => keccak256(addr));

// Create tree
let merkleTree = new MerkleTree(leaves, keccak256, { sortPairs: true });
// Get root
let rootHash = merkleTree.getRoot().toString("hex");

// Pretty-print tree
console.log(merkleTree.toString());
console.log(rootHash.toString());

let address = "0x287f0b854a2ba9dc3e8572c68bdabd949819f119";
let hashedAddress = keccak256(address);
let proof = merkleTree.getHexProof(hashedAddress);
console.log(proof); // This proof should be sent to server

// Check proof
let v = merkleTree.verify(proof, hashedAddress, rootHash);
console.log(v); // returns true
