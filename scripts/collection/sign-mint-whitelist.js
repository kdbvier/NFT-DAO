const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { readFileSync, writeFileSync } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");
const { EtherscanProvider } = require("@ethersproject/providers");

function getDeployedInstance(name, address) {
  return ethers.getContractFactory(name).then((f) => f.attach(address));
}

async function main() {
  const proxy = "0x65619617c17bcdA3a502c8f6E39b76A03be91812";
  const proof = [
    "0xad9729a4fb2a380a8e1fb85075a41435939aebc4babdd3ba93b7e02dfafcae7f",
  ];
  const Forwarder = await ethers.getContractFactory(
    "MinimalForwarderUpgradeable"
  );
  const forwarder = await Forwarder.attach(MinimalForwarder);
  const collection = await getDeployedInstance("ERC721Collection", proxy);

  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;
  const data = collection.interface.encodeFunctionData("whitelistedMint", [
    "mintedTokenURI",
    proof,
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
