require("dotenv").config();

const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { readFileSync, writeFileSync } = require("fs");
const { getAddress } = require("ethers/lib/utils");
const hre = require("hardhat");
const { constants } = require("ethers");
const { calculateProxyAddress } = require("@gnosis.pm/safe-contracts");
const { proxyFactory, safeL2Singleton } = require("../../src/contract");
const { MinimalForwarder } = require("../../relayer/forwarder.json");

async function main() {
  const Forwarder = await ethers.getContractFactory(
    "MinimalForwarderUpgradeable"
  );
  const forwarder = await Forwarder.attach(MinimalForwarder);

  const { dao } = JSON.parse(readFileSync("deployed/daoContract.json"));
  const { GenericProxyFactory } = JSON.parse(
    readFileSync("deployed/genericProxy.json")
  );

  const DaoProxyFactory = await ethers.getContractFactory(
    "GenericProxyFactory"
  );
  const daoProxyFactory = await DaoProxyFactory.attach(GenericProxyFactory);
  const { SIGNER_KEY: signer, ADMIN_KEY: admin } = process.env;
  const from = new ethers.Wallet(signer).address;
  const party = new ethers.Wallet(admin).address;

  // // Setup gnosis wallet
  const singleton = await safeL2Singleton(
    hre,
    process.env.SAFE_SINGLETON_ADDRESS
  );
  const factory = await proxyFactory(hre, process.env.SAFE_PROXY_ADDRESS);
  const signers = [from, party];
  const threshold = 1;
  const fallbackHandler = getAddress(constants.AddressZero);
  const nonce = new Date().getTime();
  const setupData = singleton.interface.encodeFunctionData("setup", [
    signers,
    threshold,
    getAddress(constants.AddressZero),
    "0x",
    fallbackHandler,
    getAddress(constants.AddressZero),
    0,
    getAddress(constants.AddressZero),
  ]);

  // ? not require at this point.
  // const predictedAddress = await calculateProxyAddress(
  //   factory,
  //   singleton.address,
  //   setupData,
  //   nonce
  // );

  // console.log(`calldata is ${setupData}`);
  // console.log(`nonce is ${nonce}`);
  // console.log(`Deploy safe address to ${predictedAddress}`);

  // NOTE: This will immediately create safe...
  // await factory
  //   .createProxyWithNonce(singleton.address, setupData, nonce)
  //   .then((tx) => tx.wait());

  // Safe setup ends

  const config = {
    isDAO: true,
    dao: {
      masterCopy: dao,
      safeFactory: process.env.SAFE_PROXY_ADDRESS,
      singleton: process.env.SAFE_SINGLETON_ADDRESS,
      setupData: setupData,
      nonce: nonce,
      hasTreasury: false,
      safeProxy: ethers.constants.AddressZero,
      creator: from,
    },
    forwarder: MinimalForwarder,
  };

  const data = daoProxyFactory.interface.encodeFunctionData("createDAOProxy", [
    config,
  ]);

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
