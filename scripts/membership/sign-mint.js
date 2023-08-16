const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { readFileSync, writeFileSync } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");
const { EtherscanProvider } = require("@ethersproject/providers");

function getDeployedInstance(name, address) {
  return ethers.getContractFactory(name).then((f) => f.attach(address));
}

async function main() {
  const proxy = "0xFEf571f8078C04592F06bA4f76448dC8B78d32B2";
  const tier = "SILVER";

  const collection = await getDeployedInstance("MembershipCollection", proxy);

  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;

  const data = await collection.mintToCaller(from, "TokenURI", tier, {
    value: ethers.utils.parseUnits("0.0001", "ether"),
  });

  console.log(data);
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
