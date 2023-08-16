const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { writeFileSync } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");
const getDeployedInstance = require("../common/deployed-instance");

async function main() {
  const proxy = "0x1759819cA15703A438EB2977E4376003E0E330Ef";
  const Forwarder = await ethers.getContractFactory(
    "MinimalForwarderUpgradeable"
  );
  const forwarder = await Forwarder.attach(MinimalForwarder);

  const collection = await getDeployedInstance("ERC721Collection", proxy);

  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;
  const data = collection.interface.encodeFunctionData("withdraw", []);

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
