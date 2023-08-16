const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { writeFileSync } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");

function getDeployedInstance(name, address) {
  return ethers.getContractFactory(name).then((f) => f.attach(address));
}

async function main() {
  // Proxy for DAO
  const proxy = "0x0d722486201Df644a9D4F356d3708C2f2C05a384";
  const treasury = "";

  const Forwarder = await ethers.getContractFactory(
    "MinimalForwarderUpgradeable"
  );
  const forwarder = await Forwarder.attach(MinimalForwarder);
  const collection = await getDeployedInstance("CreatorDAO", proxy);

  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;
  const data = collection.interface.encodeFunctionData("setTreasury", [
    treasury,
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
