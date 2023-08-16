require("dotenv").config();

const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { readFileSync, writeFileSync, readFile } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");

async function main() {
  const Forwarder = await ethers.getContractFactory(
    "MinimalForwarderUpgradeable"
  );

  const forwarder = await Forwarder.attach(MinimalForwarder);
  const { collection } = JSON.parse(readFileSync("deployed/productNFT.json"));
  const { GenericProxyFactory } = JSON.parse(
    readFileSync("deployed/genericProxy.json")
  );

  const { discountContract, decirProxy } = JSON.parse(
    readFileSync("deployed/discount-treasury.json")
  );

  const { splitter } = JSON.parse(readFileSync("deployed/royalty.json"));

  // This should be generic proxy here
  const CollectionFactory = await ethers.getContractFactory(
    "GenericProxyFactory"
  );
  const collectionFactory = await CollectionFactory.attach(GenericProxyFactory);
  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;

  // ["Proxy A", "P_A", owner.address, true, masterProduct.address],
  //       [baseURI, royaltyABps, zeroAddress, 100, ethers.utils.parseEther("1")]
  const args = {
    isCollection: true,
    collection: {
      deployConfig: {
        name: "Proxy A",
        symbol: "P_A",
        owner: from,
        masterCopy: collection,
      },
      runConfig: {
        baseURI: process.env.IPFS_BASE_URL,
        royaltiesBps: 250, // 2.5%
        royaltyAddress: ethers.constants.AddressZero,
        maxSupply: 1234,
        floorPrice: await ethers.utils.parseUnits("0.001", "ether"),
      },
    },
    decirTreasury: decirProxy,
    discount: discountContract,
    forwarder: MinimalForwarder,
  };

  const data = collectionFactory.interface.encodeFunctionData(
    "createCollectionProxy",
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
