const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { readFileSync, writeFileSync } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");
const { EtherscanProvider } = require("@ethersproject/providers");

function getDeployedInstance(name, address) {
  return ethers.getContractFactory(name).then((f) => f.attach(address));
}

async function main() {
  const proxy = "0x1cAcAE8BE3f689Cec5C0d01c95D15C7071BA0232"; // Decir treasury helper

  const treasury = await getDeployedInstance("DecirTreasury", proxy);

  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;

  const data = await treasury.primarySaleFeeRecipient();

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
