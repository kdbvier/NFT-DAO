require("dotenv").config();

const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const getDeployedInstance = require("../common/deployed-instance");
const { readFileSync, writeFileSync } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");

async function main() {
  const Forwarder = await ethers.getContractFactory(
    "MinimalForwarderUpgradeable"
  );
  const forwarder = await Forwarder.attach(MinimalForwarder);
  // load deployed contract

  const deployedAddress = "0xb6B1b4fA30d8Bd0f2Fd8a2Db71a0f18Bd984827B";
  const splitterInstance = await getDeployedInstance(
    "RoyaltySplitter",
    deployedAddress
  );

  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;
  // const admin = new ethers.Wallet(adminkey).address;

  // call release function with correct address
  const data = splitterInstance.interface.encodeFunctionData("release", [from]);

  const result = await signMetaTxRequest(signer, forwarder, {
    to: splitterInstance.address,
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
