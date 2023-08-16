const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { readFileSync, writeFileSync } = require("fs");
const web3 = require("web3");

function getInstance(name) {
  const address = JSON.parse(
    readFileSync("relayer/NFTCollectionImplementation.json")
  )[name];
  if (!address) throw new Error(`Contract ${name} not found in json file`);
  return ethers.getContractFactory(name).then((f) => f.attach(address));
}

function getDeployedInstance(name, address) {
  return ethers.getContractFactory(name).then((f) => f.attach(address));
}

async function main() {
  const forwarder = await getInstance("MinimalForwarder");

  const proof = JSON.parse(readFileSync("verify/merkleRoot.json"))["proof"];
  const collection = await getDeployedInstance(
    "ERC721NFTCustom",
    "0xAdF7A3A622A5dD224cDa174f47B1c7a053Dbf665"
  );

  console.log(JSON.stringify(proof).replace(/"/g, ""));

  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;
  const data = collection.interface.encodeFunctionData("checkValidity", [
    proof,
  ]);

  const result = await signMetaTxRequest(signer, forwarder, {
    to: collection.address,
    from,
    data,
  });

  writeFileSync("tmp/request.json", JSON.stringify(result, null, 2));
  console.log(`Signature: `, result.signature);
  console.log(`Request: `, result.request);
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
