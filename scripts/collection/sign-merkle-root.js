const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { writeFileSync } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");
const getDeployedInstance = require("../common/deployed-instance");

async function main() {
  const proxy = "0x65619617c17bcdA3a502c8f6E39b76A03be91812";
  const root =
    "3032cb4499458581f7377b88c6dfd16c6e3b2ff1b8c92bc27b3dc651e9279c3b";
  const Forwarder = await ethers.getContractFactory(
    "MinimalForwarderUpgradeable"
  );
  const forwarder = await Forwarder.attach(MinimalForwarder);

  const collection = await getDeployedInstance("ERC721Collection", proxy);

  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;
  const data = collection.interface.encodeFunctionData("updateMerkleRoot", [
    `0x${root}`,
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
