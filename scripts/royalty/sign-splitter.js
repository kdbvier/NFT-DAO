require("dotenv").config();

const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { readFileSync, writeFileSync } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");

async function main() {
  const Forwarder = await ethers.getContractFactory(
    "MinimalForwarderUpgradeable"
  );
  const forwarder = await Forwarder.attach(MinimalForwarder);

  const { splitter } = JSON.parse(readFileSync("deployed/royalty.json"));
  const { GenericProxyFactory } = JSON.parse(
    readFileSync("deployed/genericProxy.json")
  );

  const SplitterProxyFactory = await ethers.getContractFactory(
    "GenericProxyFactory"
  );

  const { discountContract, decirProxy } = JSON.parse(
    readFileSync("deployed/discount-treasury.json")
  );

  const splitterFactory = await SplitterProxyFactory.attach(
    GenericProxyFactory
  );
  const { SIGNER_KEY: signer, ADMIN_KEY: admin } = process.env;
  const from = new ethers.Wallet(signer).address;
  const party = new ethers.Wallet(admin).address;

  const args = {
    receivers: [from, party],
    shares: [ethers.utils.parseUnits("50"), ethers.utils.parseUnits("50")],
    masterCopy: splitter, //static info
    creator: from,
    decirContract: decirProxy,
    discountContract: discountContract,
    forwarder: MinimalForwarder, // static info
  };

  writeFileSync("verify/cloneSplitter.js", JSON.stringify(args, null, 2));

  const data = splitterFactory.interface.encodeFunctionData(
    "createRoyaltyProxy",
    [args]
  );

  const result = await signMetaTxRequest(signer, forwarder, {
    to: GenericProxyFactory,
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
