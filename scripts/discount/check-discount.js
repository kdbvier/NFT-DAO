const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { readFileSync, writeFileSync } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");
const { EtherscanProvider } = require("@ethersproject/providers");

function getDeployedInstance(name, address) {
  return ethers.getContractFactory(name).then((f) => f.attach(address));
}

async function main() {
  const proxy = "0x28Fb2A2507cB0c93e434b7EBCB28107Fab41CE51"; // Decir discount helper

  const discountContract = await getDeployedInstance("Discounts", proxy);

  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;

  let tokenId = 0;
  const data = await discountContract.isDiscountApplied(from, tokenId);

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
