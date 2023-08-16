const { ethers } = require("hardhat");
const { signMetaTxRequest } = require("../../src/signer");
const { readFileSync, writeFileSync } = require("fs");
const { MinimalForwarder } = require("../../relayer/forwarder.json");
const { EtherscanProvider } = require("@ethersproject/providers");

function getDeployedInstance(name, address) {
  return ethers.getContractFactory(name).then((f) => f.attach(address));
}

async function main() {
  const proxy = "0x1759819cA15703A438EB2977E4376003E0E330Ef";
  const collection = await getDeployedInstance("ERC721Collection", proxy);
  const { SIGNER_KEY: signer } = process.env;
  const from = new ethers.Wallet(signer).address;

  const data = await collection.mintToCaller(
    from,
    "https://ikzttp.mypinata.cloud/ipfs/QmQFkLSQysj94s5GvTHPyzTxrawwtjgiiYS2TBLgrvw8CW/9231",
    { value: ethers.utils.parseUnits("0.001", "ether") }
  );

  console.log(data);

  // const result = await signMetaTxRequest(signer, forwarder, {
  //   to: collection.address,
  //   from,
  //   data,
  // });

  // writeFileSync("tmp/request.json", JSON.stringify(result, null, 2));
  // console.log(`Signature: `, result.signature);
  // console.log(`Request: `, result.request);
}

if (require.main === module) {
  main()
    .then(() => process.exit(0))
    .catch((error) => {
      console.error(error);
      process.exit(1);
    });
}
